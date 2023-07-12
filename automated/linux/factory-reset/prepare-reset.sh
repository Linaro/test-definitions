#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2022 Foundries.io Ltd.

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE
TYPE="factory_reset"
ADDITIONAL_TYPE=""
LABEL=""

usage() {
    echo "\
    Usage: $0 [-t <factory_reset|factory_reset_keep_sota|factory_reset_keep_sota_docker>]
              [-a <factory_reset|factory_reset_keep_sota|factory_reset_keep_sota_docker>]

    -t <factory_reset|factory_reset_keep_sota|factory_reset_keep_sota_docker>
        factory_reset: Full reset, removes contents of /etc/ and /var/
        factory_reset_keep_sota: Keeps /var/sota without changes
        factory_reset_keep_sota_docker: Keeps /var/sota and /var/lib without changes
    -a <factory_reset|factory_reset_keep_sota|factory_reset_keep_sota_docker>
        same as -t. Allows to create 2 files and test the priority order
    -l <target label>
        Adds a label/tag to the [pacman] section of the toml. This forces aktualizr-lite
        to use the tag and avoids possible unintentional OTA update.
    "
}

while getopts "t:a:l:h" opts; do
    case "$opts" in
        t) TYPE="${OPTARG}";;
        a) ADDITIONAL_TYPE="${OPTARG}";;
        l) LABEL="${OPTARG}";;
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

mkdir -p /etc/sota/conf.d
cp z-99-aklite-callback.toml /etc/sota/conf.d/
if [ -n "${LABEL}" ]; then
    echo "${LABEL}" >> /etc/sota/tag
fi
# create signal files
touch /var/sota/ota.signal
touch /var/sota/ota.result

#systemctl mask aktualizr-lite
# enabling lmp-device-auto-register will fail because aklite is masked
systemctl enable --now lmp-device-auto-register || error_fatal "Unable to register device"

while ! systemctl is-active aktualizr-lite; do
    echo "Waiting for aktualizr-lite to start"
    sleep 1
done

while ! journalctl --no-pager -u aktualizr-lite | grep "Device is up-to-date"; do
    echo "Waiting for aktualizr-lite to complete initialization"
    sleep 1
done

ls -l /etc/sota
ls -l /var/sota

if [ -f /etc/sota/conf.d/z-99-aklite-callback.toml ]; then
    report_pass "${TYPE}-aklite-callback-created"
else
    report_fail "${TYPE}-aklite-callback-created"
fi

if [ -f /var/sota/sql.db ]; then
    report_pass "${TYPE}-device-registration"
else
    report_fail "${TYPE}-device-registration"
fi
touch "/var/.${TYPE}"
if [ -n "${ADDITIONAL_TYPE}" ]; then
    touch "/var/.${ADDITIONAL_TYPE}"
fi
