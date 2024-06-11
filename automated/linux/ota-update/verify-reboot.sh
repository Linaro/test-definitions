#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2021 Foundries.io Ltd.

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE
REF_TARGET_VERSION=1
UBOOT_VAR_TOOL=fw_printenv
export UBOOT_VAR_TOOL
UBOOT_VAR_SET_TOOL=fw_setenv
export UBOOT_VAR_SET_TOOL
U_BOOT_VARIABLE_NAME="foobar"
U_BOOT_VARIABLE_VALUE="baz"
DEBUG="false"

usage() {
    echo "\
    Usage: $0 [-u <u-boot variable read>] [-s <u-boot variable set>] [-v <expected version>] [-V <variable name>] [-w <variable value>] [-d <true|false>]

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
    -V u-boot variable name to be set before the OTA upgrade
        It is expected that this variable will be preserved through
        the update process. Default: foobar
    -w u-boot variable value. This is assigned to the variable set
        with -v flag. Default: baz
    -d <true|false> Enables more debug messages. Default: false
    "
}

while getopts "u:s:v:V:w:d:h" opts; do
    case "$opts" in
        u) UBOOT_VAR_TOOL="${OPTARG}";;
        s) UBOOT_VAR_SET_TOOL="${OPTARG}";;
        v) REF_TARGET_VERSION="${OPTARG}";;
        w) U_BOOT_VARIABLE_VALUE="${OPTARG}";;
        V) U_BOOT_VARIABLE_NAME="${OPTARG}";;
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

ref_bootcount_after_upgrade=0
ref_rollback_after_upgrade=0
ref_bootupgrade_available_after_upgrade=0
ref_upgrade_available_after_upgrade=0
ref_fiovb_is_secondary_boot_after_upgrade=0
. /usr/lib/firmware/version.txt
# shellcheck disable=SC2154
ref_bootfirmware_version_after_upgrade="${bootfirmware_version}"

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

if [ "${TYPE}" = "uboot" ]; then
    if [ -n "${U_BOOT_VARIABLE_NAME}" ]; then
        uboot_variable_after_upgrade=$(uboot_variable_value "${U_BOOT_VARIABLE_NAME}")
        compare_test_value "${TYPE}_uboot_variable_value_after_upgrade" "${U_BOOT_VARIABLE_VALUE}" "${uboot_variable_after_upgrade}"
    else
        report_skip "${TYPE}_uboot_variable_value_after_upgrade"
    fi
fi
. /etc/os-release
# shellcheck disable=SC2154
compare_test_value "target_version_after_upgrade" "${REF_TARGET_VERSION}" "${IMAGE_VERSION}"
cat /etc/os-release
cat /boot/loader/uEnv.txt

if [ "${DEBUG}" = "true" ]; then
    journalctl --no-pager -u aktualizr-lite
fi
