#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2024 Foundries.io Ltd.

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE
FORCE="false"
APPLIST=""
DEFAULTAPPLIST=""
DEBUG="false"
SOTA_CONFDIR="/etc/sota/conf.d"
CONDUCTOR_URL=""
DEFAULTAPP_COUNT=0
APP_COUNT=0

usage() {
    echo "\
    Usage: $0 [-f <true|false>] [-e <app list>] [-a <app list>] [-d <true|false> ] [-u <conductor url>]

    -f <true|false>
        If set to true, empty apps list is allowed to be set
    -e <default app list>
        Comma separated list of apps that should be running after registration
    -a <app list>
        Comma separated list of apps to enable in this test.
        The list should be different than the list of apps at registration
    -u <conductor url>
        URL of the conductor service that performs API actions
    -d <true|false> Enables more debug messages. Default: false
    "
}

while getopts "f:a:e:d:u:h" opts;
do
    case "$opts" in
        f) FORCE="${OPTARG}";;
        a) APPLIST="${OPTARG}";;
        e) DEFAULTAPPLIST="${OPTARG}";;
        d) DEBUG="${OPTARG}";;
        u) CONDUCTOR_URL="${OPTARG}";;
        h|*) usage ; exit 1 ;;
    esac
done

# the script works only on builds with aktualizr-lite
# and lmp-device-auto-register

! check_root && error_msg "You need to be root to run this script."
create_out_dir "${OUTPUT}"

if [ -z "${CONDUCTOR_URL}" ]; then
    error_fatal "CONDUCTOR_URL is not set"
fi

if [ -z "${DEFAULTAPPLIST}" ]; then
    error_fatal "DEFAULTAPPLIST must not be empty"
fi

# configure aklite callback
cp aklite-callback.sh /var/sota/
chmod 755 /var/sota/aklite-callback.sh
mkdir -p "${SOTA_CONFDIR}"
cp z-99-aklite-callback.toml "${SOTA_CONFDIR}"
cp z-99-aklite-disable-reboot.toml "${SOTA_CONFDIR}"

report_pass "create-aklite-callback"

# create signal files
touch /var/sota/ota.signal
touch /var/sota/ota.result
report_pass "create-signal-files"

# enabling lmp-device-auto-register variant
systemctl enable --now lmp-device-auto-register || error_fatal "Unable to register device"

while ! systemctl is-active aktualizr-lite;
do
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
report_pass "install-post-received"

OIFS=$IFS
IFS=','
for default_app in ${DEFAULTAPPLIST}
do
    DEFAULTAPP_COUNT=$((DEFAULTAPP_COUNT+1))
    if docker ps | grep "${default_app}"; then
        report_pass "default_${default_app}_running"
    else
        report_fail "default_${default_app}_running"
    fi
done

IFS=$OIFS


AKLITE_START_OLD=$(systemctl show --property=ActiveEnterTimestampMonotonic --value aktualizr-lite)

# ask conductor to update apps list for the device
. /etc/os-release
# LMP_FACTORY is defined in os-release
DEVICE_NAME=$(head -n 1 /etc/hostname)

# compose list of apps to request for
# done in 2 steps to avoid issues with IFS
AAPPLIST=""
OIFS=$IFS
IFS=','
for app in ${APPLIST}
do
    AAPPLIST="${AAPPLIST} ${app}"
done

IFS=$OIFS

JSON_APPS_LIST="["
for app in ${AAPPLIST}
do
    APP_COUNT=$((APP_COUNT+1))
    JSON_APPS_LIST="${JSON_APPS_LIST}\"${app}\","
done

if [ "${APP_COUNT}" -eq 0 ]; then
    JSON_APPS_LIST="${JSON_APPS_LIST}]"
else
    JSON_APPS_LIST="${JSON_APPS_LIST%?}]"
fi

echo "Sending JSON: ${JSON_APPS_LIST}"

if [ -n "${APPLIST}" ]; then
    curl -X POST "${CONDUCTOR_URL}/api/test/apps/${LMP_FACTORY}/${DEVICE_NAME}/" \
        -H "Content-Type: application/json" \
        -d "{\"apps_list\": ${JSON_APPS_LIST}}"
else
    if [ "${FORCE}" = "true" ] || [ "${FORCE}" = "True" ]; then
        curl -X POST "${CONDUCTOR_URL}/api/test/apps/${LMP_FACTORY}/${DEVICE_NAME}/" \
            -H "Content-Type: application/json" \
            -d "{\"apps_list\": ${JSON_APPS_LIST}, \"force\": true}"
    fi
fi

# wait for fioconfig to pick the new list. Wait for aklite-restart
AKLITE_START_NEW=$(systemctl show --property=ActiveEnterTimestampMonotonic --value aktualizr-lite)
while [ "${AKLITE_START_OLD}" -eq "${AKLITE_START_NEW}" ];
do
    echo "Waiting for aktualizr-lite to restart"
    sleep 1
    AKLITE_START_NEW=$(systemctl show --property=ActiveEnterTimestampMonotonic --value aktualizr-lite)
done

# reset the signal list
echo "" > /var/sota/ota.signal

# if there are apps added, wait for install-post signal
# this isn't perfect and will fail if there are apps added and removed at the same time
if [ "${APP_COUNT}" -gt "${DEFAULTAPP_COUNT}" ]; then
    while ! grep "install-post" /var/sota/ota.signal
    do
        echo "Sleeping 1s"
        sleep 1
        cat /var/sota/ota.signal
    done
fi

if [ "${APP_COUNT}" -eq 0 ]; then
    # wait for check-for-update-post signal
    while ! grep "check-for-update-post" /var/sota/ota.signal
    do
        echo "Sleeping 1s"
        sleep 1
        cat /var/sota/ota.signal
    done
fi
OIFS=$IFS
IFS=','
for app in ${APPLIST}
do
    if docker ps | grep "${app}"; then
        report_pass "${app}_running"
    else
        report_fail "${app}_running"
    fi
done

IFS=$OIFS

# check if the default apps are turned off
if [ "${APP_COUNT}" -eq 0 ]; then
    OIFS=$IFS
    IFS=','
    for default_app in ${DEFAULTAPPLIST}
    do
        DEFAULTAPP_COUNT=$((DEFAULTAPP_COUNT+1))
        if docker ps | grep "${default_app}"; then
            report_fail "default_after_${default_app}_running"
        else
            report_pass "default_after_${default_app}_running"
        fi
    done
fi

if [ "${DEBUG}" = "true" ]; then
    journalctl --no-pager -u aktualizr-lite
fi
