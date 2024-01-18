#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2023 Foundries.io Ltd.

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE
ROOT="/sysroot"
NEXT_TARGET=""
# Default threshold is 3%. It can be changed in settings
OTA_THRESHOLD=90
# FILL_SIZE is a percentage of the space remaining after
# update that will be filled with random data. Number bigger
# than 100 means there should not be enough space for the
# OTA update
FILL_SIZE=99

usage() {
    echo "\
    Usage: $0 [-t <kernel|uboot>] [-u <u-boot var read>] [-s <u-boot var set>] [-o <ostree|ostree+compose_apps>]

    -r <root directory>
        Root mount will determine the device that all calculations are made for
    -n <next target number>
        ID of the target the device is updating to. It is assumed this is
        a platform type target with single tag.
    -t <ota threshold>
        Percentage amount of disk space that can be filled in after OTA
    -f <fill size>
        Percentage amount of fill before OTA download. 100% means the OTA
        update will happen with exact OTA threshold. Amounts over 100% will
        prevent OTA update as aktualizr-lite should not allow OTA download.
    "
}

while getopts "r:n:t:f:h" opts; do
    case "$opts" in
        r) ROOT="${OPTARG}";;
        n) NEXT_TARGET="${OPTARG}";;
        t) OTA_THRESHOLD="${OPTARG}";;
        f) FILL_SIZE="${OPTARG}";;
        h|*) usage ; exit 1 ;;
    esac
done

# the script works only on builds with aktualizr-lite
# and lmp-device-auto-register

! check_root && error_msg "You need to be root to run this script."
create_out_dir "${OUTPUT}"

# configure aklite callback
cp aklite-callback.sh /var/sota/
chmod 755 /var/sota/aklite-callback.sh
# disable reboot by aklite
mkdir -p /etc/sota/conf.d
cp z-99-aklite-callback.toml /etc/sota/conf.d/
# force OTA threshold in .toml
RESERVED_PERCENTAGE=$(echo "100-${OTA_THRESHOLD}" | bc -l)
echo "sysroot_ostree_reserved_space_percentage = ${RESERVED_PERCENTAGE}" >> /etc/sota/conf.d/z-99-aklite-callback.toml

report_pass "create-aklite-callback"
# create signal files
touch /var/sota/ota.signal
touch /var/sota/ota.result
report_pass "create-signal-files"

if [ -z "${NEXT_TARGET}" ]; then
    error_msg "NEXT_TARGET missing"
    exit 0;
fi

# mask aklite to perform pre-test setup (fill in the space)
systemctl mask aktualizr-lite
# auto register
systemctl enable --now lmp-device-auto-register || true  # exit code will not be 0 as aklite is masked

while ! journalctl --no-pager -u lmp-device-auto-register | grep "Device is now registered"
do
    echo "Waiting for device registration"
    sleep 1
done
cat /var/sota/sota.toml
df -B1
# retrieve repo URL from sota.toml
REPO_URL=$(grep repo_server /var/sota/sota.toml | awk '{gsub("\"","");print $3}')
OSTREE_URL=$(grep ostree_server /var/sota/sota.toml | awk '{gsub("\"","");print $3}')
. /etc/os-release
curl -o targets.json -H "x-ats-tags:${LMP_FACTORY_TAG}" --cert /var/sota/client.pem --cacert /var/sota/root.crt --key /var/sota/pkey.pem "${REPO_URL}/targets.json"
SEARCH_STRING=".signed.targets.\"${LMP_MACHINE}-lmp-${NEXT_TARGET}\".custom.\"delta-stats\".sha256"
DELTA=$(jq -r "${SEARCH_STRING}" targets.json)
if [ -z "${DELTA}" ]; then
    error_msg "Static delta not available for target ${LMP_MACHINE}-lmp-${NEXT_TARGET}"
    exit 0;
fi
curl -o delta.json -skL --cert /var/sota/client.pem --cacert /var/sota/root.crt --key /var/sota/pkey.pem "${OSTREE_URL}/delta-stats/${DELTA}"
cat delta.json
# obtain current OSTREE_SHA from ostree admin status
ostree admin status
CURRENT_OSTREE_SHA=$(ostree admin status | grep "\* lmp" | awk '{sub(/\..*/, ""); print $3}')
if [ -z "${CURRENT_OSTREE_SHA}" ]; then
    error_msg "ostree sha not found"
    exit 0;
fi
SIZE_SEARCH_STRING=".[].\"${CURRENT_OSTREE_SHA}\".u_size"
DELTA_SIZE=$(jq -r "${SIZE_SEARCH_STRING}" delta.json)
if [ -z "${DELTA_SIZE}" ] || [ "${DELTA_SIZE}" = "null" ]; then
    error_msg "Size of static delta for update from ${CURRENT_OSTREE_SHA} not found"
    exit 1;
fi

# check how much disk is free
DEVICE=$(df -h | grep "${ROOT}" | cut -d" " -f1)
TOTAL=$(df -B1 --output=size,avail,target | grep "${ROOT}" | awk '{print $1}')
FREE=$(df -B1 --output=size,avail,target | grep "${ROOT}" | awk '{print $2}')
BLOCK_SIZE=$(dumpe2fs -h "${DEVICE}" | grep "Block size" | awk '{print $3}')

# check what percentage of disk will the OTA take
MAX_BYTES_AVAILABLE=$(echo "s=${TOTAL}*(${OTA_THRESHOLD}/100);scale=0;s/1" | bc -l)
BYTES_IN_USE=$(echo "${TOTAL}-${FREE}" | bc -l)
MAX_BYTES_AVAILABLE_FOR_UPDATE=$(echo "${MAX_BYTES_AVAILABLE}-${BYTES_IN_USE}" | bc -l)
AFTER_OTA=$(echo "${MAX_BYTES_AVAILABLE_FOR_UPDATE}-${DELTA_SIZE}" | bc -l)

if [ "${AFTER_OTA}" -lt 0 ]; then
    error_msg "Disk already filled above threshold"
    exit 0;
fi

# fill in disk so only ~1% is left after OTA (default value)
# it is assumed that there is enough disk space to pefrorm the test
# If FILL_SIZE > 100, the test will check if aklite aborts the OTA
# Please note the calculations might be slightly wrong due to rounding
# It is advised to use a larger number (>106) to force download failure
TO_FILL=$(echo "s=${AFTER_OTA}*(${FILL_SIZE}/100)/${BLOCK_SIZE};scale=0;s/1" | bc -l)

dd if=/dev/urandom of=fill_file bs="${BLOCK_SIZE}" count="${TO_FILL}"
# Show details about generated file and disk situation
# This helps debugging when rounding errors happen.
ls -l
df -B1
systemctl unmask aktualizr-lite
systemctl start aktualizr-lite

while ! systemctl is-active aktualizr-lite; do
    echo "Waiting for aktualizr-lite to start"
    sleep 1
done

if [ "${FILL_SIZE}" -gt 100 ]; then
    # no OTA should be performed
    # wait for 'install-post' signal
    while ! grep "install-post" /var/sota/ota.signal && ! grep "download-post" /var/sota/ota.signal
    do
        echo "Sleeping 1s"
        sleep 1
        cat /var/sota/ota.signal
    done

    if grep "download-post" /var/sota/ota.signal; then
        if (journalctl --no-pager -u aktualizr-lite | grep "Fetching ostree commit"); then
            report_fail "full-disk-abort-download"
        else
            report_pass "full-disk-abort-download"
        fi
    fi
    if grep "install-post" /var/sota/ota.signal; then
        report_fail "full-disk-abort-download"
    fi
else
    # OTA should be performed
    # Find similar line in aklite logs
    # ostree-pull: 18 delta parts, 3 loose fetched; 26460 KiB transferred in 23 seconds; 0 bytes content written
    runtime="10 minutes"
    endtime=$(date -ud "$runtime" +%s)
    FOUND=0

    while [ ! "${FOUND}" -eq 1 ]; do
        if [ "$(date -u +%s)" -ge "$endtime" ]; then
            echo "OTA static delta not completed after ${runtime}"
            report_fail "ota-static-delta-update"
            break
        elif (journalctl --no-pager -u aktualizr-lite | grep "delta parts"); then
            echo "OTA static delta update done"
            FOUND=1
            journalctl --no-pager -u aktualizr-lite
            df -B1
            report_pass "ota-static-delta-update"
        fi
    done
    while ! grep "install-post" /var/sota/ota.signal
    do
        echo "Waiting 1s for aklite to complete installation"
        sleep 1
        cat /var/sota/ota.signal
    done
fi
journalctl --no-pager -u aktualizr-lite
exit 0;
