#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2026 Qualcomm Technologies, Inc. and/or its subsidiaries.
#
# Report an Arm SystemReady devicetree band ACS run as test cases. The ACS
# live image (https://github.com/ARM-software/arm-systemready) runs its
# UEFI suites (SCT, BSA, PFDI) and its Linux suites (FWTS, BSA, dt-validate
# and the other Linux tools) unattended across several reboots, stores
# every log on its BOOT_ACS partition and finally parses them with Arm's
# log parser into acs_results/acs_summary. Run this in the ACS Linux after
# "ACS automated test suites run is completed.": it reads Arm's parsed
# results (acs-results.py) and reports one case per test of the suite
# asked for.
#
# SUITE acs also checks that the ACS finished and, with BIOS_VERSION, that
# the firmware's SMBIOS BIOS version contains that string (the build of the
# firmware under test); with DUMP=true it prints a gzip tarball of the
# results (without the copy of /sys/firmware), base64 encoded between
# SYSTEMREADY-ACS-ARCHIVE markers, so a host can recreate it from the log.

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE

SUITE="acs"
RESULTS=""
BIOS_VERSION=""
DUMP="false"

usage() {
    echo "Usage: $0 [-s acs|sct|bsa|fwts|dt|standalone|pfdi|post-script]" \
        "[-r <acs_results directory>] [-b <BIOS version>] [-d true|false]" 1>&2
    exit 1
}

while getopts "s:r:b:d:h" o; do
    case "$o" in
        s) SUITE="${OPTARG}" ;;
        r) RESULTS="${OPTARG}" ;;
        b) BIOS_VERSION="${OPTARG}" ;;
        d) DUMP="${OPTARG}" ;;
        h|*) usage ;;
    esac
done

create_out_dir "${OUTPUT}"

find_results() {
    for d in /mnt/acs_results_template/acs_results /mnt/acs_results; do
        [ -d "${d}" ] && { echo "${d}"; return 0; }
    done
    dev="$(blkid -L BOOT_ACS 2> /dev/null || findfs LABEL=BOOT_ACS 2> /dev/null)"
    [ -n "${dev}" ] || return 1
    mnt="$(awk -v d="${dev}" '$1 == d { print $2; exit }' /proc/mounts)"
    if [ -z "${mnt}" ]; then
        mnt="${OUTPUT}/boot_acs"
        mkdir -p "${mnt}"
        mount -o ro "${dev}" "${mnt}" || return 1
    fi
    for d in "${mnt}/acs_results_template/acs_results" "${mnt}/acs_results"; do
        [ -d "${d}" ] && { echo "${d}"; return 0; }
    done
    return 1
}

if [ -z "${RESULTS}" ]; then
    RESULTS="$(find_results)" || RESULTS=""
fi
if [ -z "${RESULTS}" ] || [ ! -d "${RESULTS}" ]; then
    info_msg "no ACS results (BOOT_ACS partition with acs_results)"
    report_fail "acs-results"
    exit 0
fi
info_msg "ACS results: ${RESULTS}"

if [ "${SUITE}" = "acs" ]; then
    if [ -d "${RESULTS}/acs_summary/acs_jsons" ]; then
        report_pass "acs-completed"
    else
        report_fail "acs-completed"
    fi
    if [ -n "${BIOS_VERSION}" ]; then
        bios="$(cat /sys/class/dmi/id/bios_version 2> /dev/null)"
        info_msg "SMBIOS BIOS version: ${bios:-none}"
        case "${bios}" in
            *"${BIOS_VERSION}"*) report_pass "bios-version" ;;
            *) report_fail "bios-version" ;;
        esac
    fi
fi

if ! command -v python3 > /dev/null 2>&1; then
    info_msg "python3 is missing"
    report_skip "${SUITE}-results"
    exit 0
fi
python3 ./acs-results.py --results "${RESULTS}" --suite "${SUITE}" --output "${OUTPUT}"

if [ "${DUMP}" = "true" ]; then
    archive="${OUTPUT}/acs_results.tar.gz"
    top="$(dirname "${RESULTS}")"
    tar -C "${top}" -czf "${archive}" --exclude="*/linux_dump/firmware" \
        "$(basename "${RESULTS}")"
    size="$(wc -c < "${archive}")"
    sum="$(sha256sum "${archive}" | cut -d' ' -f1)"
    echo "SYSTEMREADY-ACS-ARCHIVE-BEGIN acs_results.tar.gz ${size} ${sum}"
    base64 "${archive}"
    echo "SYSTEMREADY-ACS-ARCHIVE-END"
fi
exit 0
