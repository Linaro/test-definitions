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

! check_root && error_msg "You need to be root to run this script."
create_out_dir "${OUTPUT}"

# check u-boot variables to ensure rollback happend
bootcount_after_rollback=$(uboot_variable_value bootcount)
compare_test_value "bootcount_after_rollback" 4 "${bootcount_after_rollback}"
rollback_after_rollback=$(uboot_variable_value rollback)
compare_test_value "rollback_after_rollback" 1 "${rollback_after_rollback}"
bootupgrade_available_after_rollback=$(uboot_variable_value bootupgrade_available)
compare_test_value "bootupgrade_available_after_rollback" 0 "${bootupgrade_available_after_rollback}"
upgrade_available_after_rollback=$(uboot_variable_value upgrade_available)
compare_test_value "upgrade_available_after_rollback" 0 "${upgrade_available_after_rollback}"

. /usr/lib/firmware/version.txt
bootfirmware_version_after_rollback=$(uboot_variable_value bootfirmware_version)
# shellcheck disable=SC2154
compare_test_value "bootfirmware_version_after_rollback" "${bootfirmware_version}" "${bootfirmware_version_after_rollback}"
fiovb_is_secondary_boot_after_rollback=$(uboot_variable_value fiovb.is_secondary_boot)
compare_test_value "fiovb_is_secondary_boot_after_rollback" 0 "${fiovb_is_secondary_boot_after_rollback}"

# for now ignore /etc/os-release
cat /etc/os-release
cat /boot/loader/uEnv.txt
