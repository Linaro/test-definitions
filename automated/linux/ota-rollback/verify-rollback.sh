#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2021 Foundries.io Ltd.

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE
TYPE="kernel"
UBOOT_VAR_TOOL=fw_printenv
export UBOOT_VAR_TOOL
UBOOT_VAR_SET_TOOL=fw_setenv
export UBOOT_VAR_SET_TOOL
DEBUG="false"

usage() {
    echo "\
    Usage: $0 [-type <kernel|uboot|app>] [-u <u-boot var read>] [-s <u-boot var set>] [-d <true|false>]

    -t <kernel|uboot|app>
        This determines type of corruption test
        performed:
        kernel: corrupt OTA updated kernel binary
        uboot: corrupt OTA updated u-boot binary
        app: corrupt OTA app sync
    -u <u-boot variable read tool>
        Set the name of the tool to read u-boot variables
        On the unsecured systems it will usually be
        fw_printenv. On secured systems it might be
        fiovb_printenv
    -s <u-boot variable set tool>
        Set the name of the tool to set u-boot variables
        On the unsecured systems it will usually be
        fw_setenv. On secured systems it might be
        fiovb_setenv
    -d <true|false> Enables more debug messages. Default: false
    "
}

while getopts "t:u:s:d:h" opts; do
    case "$opts" in
        t) TYPE="${OPTARG}";;
        u) UBOOT_VAR_TOOL="${OPTARG}";;
        s) UBOOT_VAR_SET_TOOL="${OPTARG}";;
        d) DEBUG="${OPTARG}";;
        h|*) usage ; exit 1 ;;
    esac
done

! check_root && error_msg "You need to be root to run this script."
create_out_dir "${OUTPUT}"

SECONDARY_BOOT_VAR_NAME="fiovb.is_secondary_boot"
if [ "${UBOOT_VAR_TOOL}" != "fw_printenv" ]; then
    SECONDARY_BOOT_VAR_NAME="is_secondary_boot"
fi

ref_bootcount_after_rollback=4
ref_rollback_after_rollback=1
ref_bootupgrade_available_after_rollback=0
ref_upgrade_available_after_rollback=0
ref_fiovb_is_secondary_boot_after_rollback=0

# check u-boot variables to ensure rollback happend
bootcount_after_rollback=$(uboot_variable_value bootcount)
compare_test_value "bootcount_after_rollback" "${ref_bootcount_after_rollback}" "${bootcount_after_rollback}"
rollback_after_rollback=$(uboot_variable_value rollback)
compare_test_value "rollback_after_rollback" "${ref_rollback_after_rollback}" "${rollback_after_rollback}"
upgrade_available_after_rollback=$(uboot_variable_value upgrade_available)
compare_test_value "upgrade_available_after_rollback" "${ref_upgrade_available_after_rollback}" "${upgrade_available_after_rollback}"
if [ -f /usr/lib/firmware/version.txt ]; then
    . /usr/lib/firmware/version.txt
    bootupgrade_available_after_rollback=$(uboot_variable_value bootupgrade_available)
    compare_test_value "bootupgrade_available_after_rollback" "${ref_bootupgrade_available_after_rollback}" "${bootupgrade_available_after_rollback}"

    # shellcheck disable=SC2154
    ref_bootfirmware_version_after_rollback="${bootfirmware_version}"
    if [ "${TYPE}" = "uboot" ]; then
        ref_bootfirmware_version_after_rollback=0
    fi
    bootfirmware_version_after_rollback=$(uboot_variable_value bootfirmware_version)
    # shellcheck disable=SC2154
    compare_test_value "bootfirmware_version_after_rollback" "${ref_bootfirmware_version_after_rollback}" "${bootfirmware_version_after_rollback}"
    fiovb_is_secondary_boot_after_rollback=$(uboot_variable_value "${SECONDARY_BOOT_VAR_NAME}")
    compare_test_value "fiovb_is_secondary_boot_after_rollback" "${ref_fiovb_is_secondary_boot_after_rollback}" "${fiovb_is_secondary_boot_after_rollback}"
else
    report_skip "bootupgrade_available_after_rollback"
    report_skip "bootfirmware_version_after_rollback"
    report_skip "fiovb_is_secondary_boot_after_rollback"
fi

if [ "${TYPE}" = "app" ]; then
    echo "Checking for broken app"
    runtime="5 minute"
    endtime=$(date -ud "$runtime" +%s)
    FOUND=0

    while [ ! "${FOUND}" -eq 1 ]; do
        if [ "$(date -u +%s)" -ge "$endtime" ]; then
            report_fail "app-rollback"
            break
        elif (journalctl --no-pager -u aktualizr-lite | grep "Finalization has failed; reason: apps start failure"); then
            echo "broken app found"
            FOUND=1
            report_pass "app-rollback"
        fi
    done
else
    report_skip "app-rollback"
fi
# for now ignore /etc/os-release
cat /etc/os-release
cat /boot/loader/uEnv.txt

if [ "${DEBUG}" = "true" ]; then
    journalctl --no-pager -u aktualizr-lite
fi
