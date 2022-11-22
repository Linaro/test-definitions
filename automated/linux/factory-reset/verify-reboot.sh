#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2022 Foundries.io Ltd.

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE
TYPE="factory_reset"

usage() {
    echo "\
    Usage: $0 [-t <factory_reset|factory_reset_keep_sota|factory_reset_keep_sota_docker>]

    -t <factory_reset|factory_reset_keep_sota|factory_reset_keep_sota_docker>
        factory_reset: Full reset, removes contents of /etc/ and /var/
        factory_reset_keep_sota: Keeps /var/sota without changes
        factory_reset_keep_sota_docker: Keeps /var/sota and /var/lib without changes
    "
}

while getopts "t:h" opts; do
    case "$opts" in
        t) TYPE="${OPTARG}";;
        h|*) usage ; exit 1 ;;
    esac
done

# the script works only on builds with aktualizr-lite
# and lmp-device-auto-register

! check_root && error_msg "You need to be root to run this script."
create_out_dir "${OUTPUT}"

ls -l /etc/
ls -l /var/sota

if [ -f /etc/sota/conf.d/z-99-aklite-callback.toml ]; then
    report_fail "${TYPE}-reset-aklite-callback-exists"
else
    report_pass "${TYPE}-reset-aklite-callback-exists"
fi

if [ "${TYPE}" = "factory_reset_keep_sota" ]; then
    # aktualizr-lite should be running
    if systemctl status --no-pager aktualizr-lite; then
        report_pass "${TYPE}-reset-aklite-running"
    else
        report_fail "${TYPE}-reset-aklite-running"
    fi
    if [ -f /var/sota/sql.db ]; then
        report_pass "${TYPE}-reset-device-registration"
    else
        report_fail "${TYPE}-reset-device-registration"
    fi
else
    # aktualizr-lite should NOT be running
    if systemctl status --no-pager aktualizr-lite; then
        report_fail "${TYPE}-reset-aklite-running"
    else
        report_pass "${TYPE}-reset-aklite-running"
    fi
    if [ -f /var/sota/sql.db ]; then
        report_fail "${TYPE}-reset-device-registration"
    else
        report_pass "${TYPE}-reset-device-registration"
    fi
fi
exit 0
