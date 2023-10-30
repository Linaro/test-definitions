#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2023 Foundries.io Ltd.

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
REF_TARGET_VERSION=""

usage() {
	echo "\
     Usage: $0 [-t <kernel|uboot>] [-u <u-boot var read>] [-s <u-boot var set>] -r <reference version>

    -t <kernel|uboot>
        This determines type of upgrade test performed:
        kernel: perform OTA upgrade without forcing firmware upgrade
        uboot: force firmware upgrade
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
    -r reference target version
	"
}

while getopts "t:u:s:r:h" opts; do
	case "$opts" in
        t) TYPE="${OPTARG}";;
        u) UBOOT_VAR_TOOL="${OPTARG}";;
        s) UBOOT_VAR_SET_TOOL="${OPTARG}";;
        r) REF_TARGET_VERSION="${OPTARG}";;
        h|*) usage ; exit 1 ;;
	esac
done

# the script works only on builds with aktualizr-lite
# and lmp-device-auto-register

! check_root && error_msg "You need to be root to run this script."
create_out_dir "${OUTPUT}"

aklite-offline run

SECONDARY_BOOT_VAR_NAME="fiovb.is_secondary_boot"
if [ "${UBOOT_VAR_TOOL}" != "fw_printenv" ]; then
    SECONDARY_BOOT_VAR_NAME="is_secondary_boot"
fi

ref_bootcount_after_upgrade=0
ref_rollback_after_upgrade=0
ref_fiovb_is_secondary_boot_after_upgrade=0

if [ "${TYPE}" = "uboot" ]; then
    # boots to secondary slot. Set to 0 on a subsequent reboot
    ref_fiovb_is_secondary_boot_after_upgrade=1
    if [ "${BOOTROM_USE_SECONDARY}" = "false" ] || [ "${BOOTROM_USE_SECONDARY}" = "False" ]; then
        ref_fiovb_is_secondary_boot_after_upgrade=0
    fi
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
bootfirmware_version_after_upgrade=$(uboot_variable_value bootfirmware_version)
compare_test_value "bootfirmware_version_after_upgrade" "${ref_bootfirmware_version_after_upgrade}" "${bootfirmware_version_after_upgrade}"
fiovb_is_secondary_boot_after_upgrade=$(uboot_variable_value "${SECONDARY_BOOT_VAR_NAME}")
compare_test_value "fiovb_is_secondary_boot_after_upgrade" "${ref_fiovb_is_secondary_boot_after_upgrade}" "${fiovb_is_secondary_boot_after_upgrade}"

. /etc/os-release
# shellcheck disable=SC2154
compare_test_value "target_version_after_upgrade" "${REF_TARGET_VERSION}" "${IMAGE_VERSION}"
cat /etc/os-release
cat /boot/loader/uEnv.txt
