#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2023 Foundries.io Ltd.

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE
TYPE="regular"
APPNAME=""
VERSION=""
DEBUG="false"
SOTA_CONFDIR="/etc/sota/conf.d"

usage() {
    echo "\
    Usage: $0 [-t <regular|corrupt>] [-a <app name>] [-d <true|false> ] [-v <expected target version>]

    -t <regular|corrupt>
        This determines type of upgrade test performed:
        regular: register with proper app. OTA should be successful
        corrupt: register with corrupt app. OTA should result in rollback
    -a <app name>
        Name of the docker app that should be running after registration
        and update
    -v <target version>
        Version of the target expected after reboot.
        Defaults to 1. Should be set to avoid bad results
    -d <true|false> Enables more debug messages. Default: false
    "
}

while getopts "t:a:v:d:h" opts; do
    case "$opts" in
        t) TYPE="${OPTARG}";;
        a) APPNAME="${OPTARG}";;
        v) VERSION="${OPTARG}";;
        d) DEBUG="${OPTARG}";;
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
mkdir -p "${SOTA_CONFDIR}"
cp z-99-aklite-callback.toml "${SOTA_CONFDIR}"
cp z-99-aklite-disable-reboot.toml "${SOTA_CONFDIR}"

report_pass "${TYPE}-create-aklite-callback"

# create signal files
touch /var/sota/ota.signal
touch /var/sota/ota.result
report_pass "${TYPE}-create-signal-files"

# enabling lmp-device-auto-register variant
if [ "${TYPE}" = "regular" ]; then
    systemctl enable --now lmp-device-auto-register || error_fatal "Unable to register device"
elif [ "${TYPE}" = "corrupt" ]; then
    systemctl enable --now lmp-device-auto-register-corrupt || error_fatal "Unable to register device"
fi

while ! systemctl is-active aktualizr-lite; do
    echo "Waiting for aktualizr-lite to start"
    sleep 1
done

# wait for 'install-post' signal
while ! grep "install-post" /var/sota/ota.signal
do
    echo "Sleeping 1s"
    sleep 1
    cat /var/sota/ota.signal
done
report_pass "${TYPE}-install-post-received"
if [ "${TYPE}" = "regular" ]; then
    journalctl --no-pager -u aktualizr-lite | grep "No reboot"
    check_return "aklite-no-reboot"
    report_skip "aklite-failing-target"
else
    journalctl --no-pager -u aktualizr-lite | grep "failing Target"
    check_return "aklite-failing-target"
    report_skip "aklite-no-reboot"
fi

. /var/sota/current-target
compare_test_value "targer_after_upgrade" "${VERSION}" "${CUSTOM_VERSION}"

if [ -n "${APPNAME}" ] && [ "${TYPE}" = "regular" ]; then
    docker ps | grep "${APPNAME}"
    check_return "app-running"
else
    report_skip "app-running"
fi

if [ "${DEBUG}" = "true" ]; then
    journalctl --no-pager -u aktualizr-lite
fi
