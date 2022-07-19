#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2021 Foundries.io Ltd.

# shellcheck disable=SC1091
. ./sh-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE
TYPE="kernel"
UBOOT_VAR_TOOL=fw_printenv
export UBOOT_VAR_TOOL
UBOOT_VAR_SET_TOOL=fw_setenv
export UBOOT_VAR_SET_TOOL

usage() {
    echo "\
    Usage: $0 [-type <kernel|uboot>]

    -t <kernel|uboot>
        This determines type of corruption test
        performed:
        kernel: corrupt OTA updated kernel binary
        uboot: corrupt OTA updated u-boot binary
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
    "
}

while getopts "t:u:s:h" opts; do
    case "$opts" in
        t) TYPE="${OPTARG}";;
        u) UBOOT_VAR_TOOL="${OPTARG}";;
        s) UBOOT_VAR_SET_TOOL="${OPTARG}";;
        h|*) usage ; exit 1 ;;
    esac
done

# the script works only on builds with aktualizr-lite
# and lmp-device-auto-register

! check_root && error_msg "You need to be root to run this script."
create_out_dir "${OUTPUT}"

SECONDARY_BOOT_VAR_NAME="fiovb.is_secondary_boot"
if [ "${UBOOT_VAR_TOOL}" != "fw_printenv" ]; then
    SECONDARY_BOOT_VAR_NAME="is_secondary_boot"
fi

ref_bootcount_after_reboot=4
ref_rollback_after_reboot=1
ref_bootupgrade_available_after_reboot=0
ref_upgrade_available_after_reboot=0
ref_fiovb_is_secondary_boot_after_reboot=0

# check u-boot variables
bootcount_after_reboot=$(uboot_variable_value bootcount)
echo "Bootcount: ${bootcount_after_reboot}"
# bootcount should be 4 despite the fact there was no boot failures in u-boot
compare_test_value "bootcount_after_reboot" "${ref_bootcount_after_reboot}" "${bootcount_after_reboot}"
rollback_after_reboot=$(uboot_variable_value rollback)
echo "Rollback: ${rollback_after_reboot}"
compare_test_value "rollback_after_reboot" "${ref_rollback_after_reboot}" "${rollback_after_reboot}"
upgrade_available_after_reboot=$(uboot_variable_value upgrade_available)
compare_test_value "upgrade_available_after_reboot" "${ref_upgrade_available_after_reboot}" "${upgrade_available_after_reboot}"
if [ -f /usr/lib/firmware/version.txt ]; then
    . /usr/lib/firmware/version.txt
    bootupgrade_available_after_reboot=$(uboot_variable_value bootupgrade_available)
    compare_test_value "bootupgrade_available_after_reboot" "${ref_bootupgrade_available_after_reboot}" "${bootupgrade_available_after_reboot}"

    # shellcheck disable=SC2154
    ref_bootfirmware_version_after_reboot="${bootfirmware_version}"
    if [ "${TYPE}" = "uboot" ]; then
        ref_bootfirmware_version_after_reboot=0
    fi
    bootfirmware_version_after_reboot=$(uboot_variable_value bootfirmware_version)
    # shellcheck disable=SC2154
    compare_test_value "bootfirmware_version_after_reboot" "${ref_bootfirmware_version_after_reboot}" "${bootfirmware_version_after_reboot}"
    fiovb_is_secondary_boot_after_reboot=$(uboot_variable_value "${SECONDARY_BOOT_VAR_NAME}")
    compare_test_value "fiovb_is_secondary_boot_after_reboot" "${ref_fiovb_is_secondary_boot_after_reboot}" "${fiovb_is_secondary_boot_after_reboot}"
else
    report_skip "bootupgrade_available_after_reboot"
    report_skip "bootfirmware_version_after_reboot"
    report_skip "fiovb_is_secondary_boot_after_reboot"
fi
