#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2021 Foundries.io Ltd.

# shellcheck disable=SC1091
. ./sh-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE
TYPE="kernel"
REF_TARGET_VERSION=1
UBOOT_VAR_TOOL=fw_printenv
export UBOOT_VAR_TOOL
UBOOT_VAR_SET_TOOL=fw_setenv
export UBOOT_VAR_SET_TOOL

usage() {
    echo "\
    Usage: $0 [-t <kernel|uboot>] [-u <u-boot variable read>] [-s <u-boot variable set>] [-v <expected version>]

    -t <kernel|uboot>
        Defauts to 'kernel'. It either enables or disables
        checking the upgrade status of u-boot firmware
    -v <target version>
        Version of the target expected after reboot.
        Defaults to 1. Should be set to avoid bad results
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

while getopts "t:u:s:v:h" opts; do
    case "$opts" in
        t) TYPE="${OPTARG}";;
        u) UBOOT_VAR_TOOL="${OPTARG}";;
        s) UBOOT_VAR_SET_TOOL="${OPTARG}";;
        v) REF_TARGET_VERSION="${OPTARG}";;
        h|*) usage ; exit 1 ;;
    esac
done

! check_root && error_msg "You need to be root to run this script."
create_out_dir "${OUTPUT}"

SECONDARY_BOOT_VAR_NAME="fiovb.is_secondary_boot"
if [ "${UBOOT_VAR_TOOL}" != "fw_printenv" ]; then
    SECONDARY_BOOT_VAR_NAME="is_secondary_boot"
fi

ref_bootcount_after_upgrade=0
ref_rollback_after_upgrade=0
ref_bootupgrade_available_after_upgrade=0
ref_upgrade_available_after_upgrade=0
ref_fiovb_is_secondary_boot_after_upgrade=0

if [ "${TYPE}" = "uboot" ]; then
    ref_bootupgrade_available_after_upgrade=1
    # boots to secondary slot. Set to 0 on a subsequent reboot
    ref_fiovb_is_secondary_boot_after_upgrade=1
    # set to 0 forcibly. It stays this way on the 1st reboot
    ref_bootfirmware_version_after_upgrade=0
else
    . /usr/lib/firmware/version.txt
    # shellcheck disable=SC2154
    ref_bootfirmware_version_after_upgrade="${bootfirmware_version}"
fi
# check u-boot variables to ensure upgrade happend
bootcount_after_upgrade=$(uboot_variable_value bootcount)
compare_test_value "bootcount_after_upgrade" "${ref_bootcount_after_upgrade}" "${bootcount_after_upgrade}"
rollback_after_upgrade=$(uboot_variable_value rollback)
compare_test_value "rollback_after_upgrade" "${ref_rollback_after_upgrade}" "${rollback_after_upgrade}"
upgrade_available_after_upgrade=$(uboot_variable_value upgrade_available)
compare_test_value "upgrade_available_after_upgrade" "${ref_upgrade_available_after_upgrade}" "${upgrade_available_after_upgrade}"
bootupgrade_available_after_upgrade=$(uboot_variable_value bootupgrade_available)
compare_test_value "bootupgrade_available_after_upgrade" "${ref_bootupgrade_available_after_upgrade}" "${bootupgrade_available_after_upgrade}"
bootfirmware_version_after_upgrade=$(uboot_variable_value bootfirmware_version)
compare_test_value "bootfirmware_version_after_upgrade" "${ref_bootfirmware_version_after_upgrade}" "${bootfirmware_version_after_upgrade}"
fiovb_is_secondary_boot_after_upgrade=$(uboot_variable_value "${SECONDARY_BOOT_VAR_NAME}")
compare_test_value "fiovb_is_secondary_boot_after_upgrade" "${ref_fiovb_is_secondary_boot_after_upgrade}" "${fiovb_is_secondary_boot_after_upgrade}"

. /etc/os-release
# shellcheck disable=SC2154
compare_test_value "target_version_after_upgrade" "${REF_TARGET_VERSION}" "${IMAGE_VERSION}"
cat /etc/os-release
cat /boot/loader/uEnv.txt
