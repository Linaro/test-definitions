#!/bin/bash
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

# check u-boot variables to ensure we're on freshly flashed device
bootcount_before_download=$(uboot_variable_value bootcount)
compare_test_value "bootcount_before_download" 0 "${bootcount_before_download}"
rollback_before_download=$(uboot_variable_value rollback)
compare_test_value "rollback_before_download" 0 "${rollback_before_download}"
bootupgrade_available_before_download=$(uboot_variable_value bootupgrade_available)
compare_test_value "bootupgrade_available_before_download" 0 "${bootupgrade_available_before_download}"
upgrade_available_before_download=$(uboot_variable_value upgrade_available)
compare_test_value "upgrade_available_before_download" 0 "${upgrade_available_before_download}"

. /usr/lib/firmware/version.txt
bootfirmware_version_before_download=$(uboot_variable_value bootfirmware_version)
# shellcheck disable=SC2154
compare_test_value "bootfirmware_version_before_download" "${bootfirmware_version}" "${bootfirmware_version_before_download}"
fiovb_is_secondary_boot_before_download=$(uboot_variable_value fiovb.is_secondary_boot)
compare_test_value "fiovb_is_secondary_boot_before_download" 0 "${fiovb_is_secondary_boot_before_download}"

# configure aklite callback
cp aklite-callback.sh /var/sota/
chmod 755 /var/sota/aklite-callback.sh

mkdir -p /etc/sota/conf.d
cp z-99-aklite-callback.toml /etc/sota/conf.d/
report_pass "create-aklite-callback"
# create signal files
touch /var/sota/ota.signal
touch /var/sota/ota.result
report_pass "create-signal-files"

#systemctl mask aktualizr-lite
# enabling lmp-device-auto-register will fail because aklite is masked
systemctl enable --now lmp-device-auto-register || error_fatal "Unable to register device"
# aktualizr-lite update
# TODO: check if there is an update to download
# if there isn't, terminate the job
# use "${upgrade_available_after_download}" for now. Find a better solution later

# wait for 'install-pre' signal
SIGNAL=$(</var/sota/ota.signal)
while [ ! "${SIGNAL}" = "install-post" ]
do
	echo "Sleeping 1s"
	sleep 1
	cat /var/sota/ota.signal
	SIGNAL=$(</var/sota/ota.signal)
	echo "SIGNAL: ${SIGNAL}."
done
report_pass "install-post-received"

#systemctl stop aktualizr-lite
#systemctl mask aktualizr-lite

bootcount_after_download=$(uboot_variable_value bootcount)
compare_test_value "bootcount_after_download" 0 "${bootcount_after_download}"
rollback_after_download=$(uboot_variable_value rollback)
compare_test_value "rollback_after_download" 0 "${rollback_after_download}"
bootupgrade_available_after_download=$(uboot_variable_value bootupgrade_available)
compare_test_value "bootupgrade_available_after_download" 0 "${bootupgrade_available_after_download}"
upgrade_available_after_download=$(uboot_variable_value upgrade_available)
compare_test_value "upgrade_available_after_download" 1 "${upgrade_available_after_download}"

. /usr/lib/firmware/version.txt
bootfirmware_version_after_download=$(uboot_variable_value bootfirmware_version)
# shellcheck disable=SC2154
compare_test_value "bootfirmware_version_after_download" "${bootfirmware_version}" "${bootfirmware_version_after_download}"
fiovb_is_secondary_boot_after_download=$(uboot_variable_value fiovb.is_secondary_boot)
compare_test_value "fiovb_is_secondary_boot_after_download" 0 "${fiovb_is_secondary_boot_after_download}"

# for now ignore /etc/os-release
cat /etc/os-release
cat /boot/loader/uEnv.txt

. /boot/loader/uEnv.txt

if [ "${upgrade_available_after_download}" -eq 1 ]; then
    # shellcheck disable=SC2154
    echo "Corrupting kernel image ${kernel_image}"
    # shellcheck disable=SC2154
    echo bad > "${kernel_image}"
else
    lava-test-raise "No-update-available"
fi

