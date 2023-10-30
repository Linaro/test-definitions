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
PACMAN_TYPE="ostree+compose_apps"
OFFLINE_UPDATE_DRIVE=""

usage() {
	echo "\
     Usage: $0 -w <offline update dir> [-t <kernel|uboot>] [-u <u-boot var read>] [-s <u-boot var set>] [-o <ostree|ostree+compose_apps>]

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
    -o ostree or ostree+compose_apps update
        These change the 'type' variable in 'pacman' section
        of the final .toml file used by aklite. Default is
        ostree+compose_apps
    -w offline update directory
	"
}

while getopts "t:u:s:o:w:h" opts; do
	case "$opts" in
        t) TYPE="${OPTARG}";;
        u) UBOOT_VAR_TOOL="${OPTARG}";;
        s) UBOOT_VAR_SET_TOOL="${OPTARG}";;
        o) PACMAN_TYPE="${OPTARG}";;
        w) OFFLINE_UPDATE_DRIVE="${OPTARG}";;
        h|*) usage ; exit 1 ;;
	esac
done

# the script works only on builds with aktualizr-lite
# and lmp-device-auto-register

! check_root && error_msg "You need to be root to run this script."
create_out_dir "${OUTPUT}"

if [ -z "${OFFLINE_UPDATE_DRIVE}" ]; then
    echo "Offline update directory missing"
    exit 1
fi

mkdir -p /etc/sota/conf.d
if [ "${PACMAN_TYPE}" = "ostree" ]; then
    cp z-99-aklite-callback-ostree.toml /etc/sota/conf.d/
else
    cp z-99-aklite-callback.toml /etc/sota/conf.d/
fi

SECONDARY_BOOT_VAR_NAME="fiovb.is_secondary_boot"
if [ "${UBOOT_VAR_TOOL}" != "fw_printenv" ]; then
    SECONDARY_BOOT_VAR_NAME="is_secondary_boot"
fi

ref_bootcount_before_upgrade=0
ref_rollback_before_upgrade=0
ref_fiovb_is_secondary_boot_before_upgrade=0
ref_bootcount_after_upgrade=0
ref_rollback_after_upgrade=0
ref_fiovb_is_secondary_boot_after_upgrade=0

# u-boot variables change when aklite starts (at least on some devices)
# check u-boot variables to ensure we're on freshly flashed device
bootcount_before_upgrade=$(uboot_variable_value bootcount)
compare_test_value "${TYPE}_bootcount_before_upgrade" "${ref_bootcount_before_upgrade}" "${bootcount_before_upgrade}"
rollback_before_upgrade=$(uboot_variable_value rollback)
compare_test_value "${TYPE}_rollback_before_upgrade" "${ref_rollback_before_upgrade}" "${rollback_before_upgrade}"

if [ -f /usr/lib/firmware/version.txt ]; then
    # boot firmware is upgreadable
    . /usr/lib/firmware/version.txt
    bootfirmware_version_before_upgrade=$(uboot_variable_value bootfirmware_version)
    # shellcheck disable=SC2154
    compare_test_value "${TYPE}_bootfirmware_version_before_upgrade" "${bootfirmware_version}" "${bootfirmware_version_before_upgrade}"
    fiovb_is_secondary_boot_before_upgrade=$(uboot_variable_value "${SECONDARY_BOOT_VAR_NAME}")
    compare_test_value "${TYPE}_fiovb_is_secondary_boot_before_upgrade" "${ref_fiovb_is_secondary_boot_before_upgrade}" "${fiovb_is_secondary_boot_before_upgrade}"
else
    report_skip "${TYPE}_bootfirmware_version_before_upgrade"
    report_skip "${TYPE}_fiovb_is_secondary_boot_before_upgrade"
fi

if [ "${TYPE}" = "uboot" ]; then
    # manually set boot firmware version to 0
    "${UBOOT_VAR_SET_TOOL}" bootfirmware_version 0
fi

mount "${OFFLINE_UPDATE_DRIVE}" /mnt
aklite-offline install --log-level 1 --src-dir /mnt

# check variables after download is completed
bootcount_after_upgrade=$(uboot_variable_value bootcount)
compare_test_value "${TYPE}_bootcount_after_upgrade" "${ref_bootcount_after_upgrade}" "${bootcount_after_upgrade}"
rollback_after_upgrade=$(uboot_variable_value rollback)
compare_test_value "${TYPE}_rollback_after_upgrade" "${ref_rollback_after_upgrade}" "${rollback_after_upgrade}"
if [ -f /usr/lib/firmware/version.txt ]; then
    . /usr/lib/firmware/version.txt
    # shellcheck disable=SC2154
    ref_bootfirmware_version_after_upgrade="${bootfirmware_version}"
    if [ "${TYPE}" = "uboot" ]; then
        ref_bootfirmware_version_after_upgrade=0
    fi
    bootfirmware_version_after_upgrade=$(uboot_variable_value bootfirmware_version)
    # shellcheck disable=SC2154
    compare_test_value "${TYPE}_bootfirmware_version_after_upgrade" "${ref_bootfirmware_version_after_upgrade}" "${bootfirmware_version_after_upgrade}"
    fiovb_is_secondary_boot_after_upgrade=$(uboot_variable_value "${SECONDARY_BOOT_VAR_NAME}")
    compare_test_value "${TYPE}_fiovb_is_secondary_boot_after_upgrade" "${ref_fiovb_is_secondary_boot_after_upgrade}" "${fiovb_is_secondary_boot_after_upgrade}"
else
    report_skip "${TYPE}_bootfirmware_version_after_upgrade"
    report_skip "${TYPE}_fiovb_is_secondary_boot_after_upgrade"
fi
