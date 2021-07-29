#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2021 Foundries.io Ltd.

# shellcheck disable=SC1091
. ./sh-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE

if [ -z "${UBOOT_VAR_TOOL}" ]; then
    UBOOT_VAR_TOOL=fw_printenv
    export UBOOT_VAR_TOOL
fi

# the script works only on builds with aktualizr-lite
# and lmp-device-auto-register

! check_root && error_msg "You need to be root to run this script."
create_out_dir "${OUTPUT}"

# check u-boot variables
bootcount_after_reboot=$(uboot_variable_value bootcount)
echo "Bootcount: ${bootcount_after_reboot}"
# bootcount should be 4 despite the fact there was no boot failures in u-boot
compare_test_value "bootcount_after_reboot" 4 "${bootcount_after_reboot}"
rollback_after_reboot=$(uboot_variable_value rollback)
echo "Rollback: ${rollback_after_reboot}"
compare_test_value "rollback_after_reboot" 1 "${rollback_after_reboot}"
bootupgrade_available_after_reboot=$(uboot_variable_value bootupgrade_available)
compare_test_value "bootupgrade_available_after_reboot" 0 "${bootupgrade_available_after_reboot}"
upgrade_available_after_reboot=$(uboot_variable_value upgrade_available)
compare_test_value "upgrade_available_after_reboot" 0 "${upgrade_available_after_reboot}"

. /usr/lib/firmware/version.txt
bootfirmware_version_after_reboot=$(uboot_variable_value bootfirmware_version)
# shellcheck disable=SC2154
compare_test_value "bootfirmware_version_after_reboot" "${bootfirmware_version}" "${bootfirmware_version_after_reboot}"
fiovb_is_secondary_boot_after_reboot=$(uboot_variable_value fiovb.is_secondary_boot)
compare_test_value "fiovb_is_secondary_boot_after_reboot" 0 "${fiovb_is_secondary_boot_after_reboot}"
