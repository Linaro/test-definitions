#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2021 Foundries.io Ltd.

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE
DEVICE_NAME=$(</etc/hostname)
export DEVICE_NAME
TARGET=""

usage() {
	echo "\
	Usage: $0
		     -t <target> [-n <device name>]

	-n <device name>
		This is the name of the registered device
	-t <target>
		This is the target that is expected to be active
	"
}

while getopts "n:t:h" opts; do
	case "$opts" in
		n) DEVICE_NAME="${OPTARG}";;
		t) TARGET="${OPTARG}";;
		h|*) usage ; exit 1 ;;
	esac
done

if [ -z "${TARGET}" ]; then
    warn_msg "TARGET variable is missing"
fi

! check_root && error_msg "You need to be root to run this script."
create_out_dir "${OUTPUT}"

FAILED=0

# check if callback is confugured
if [ -f /var/sota/aklite-callback.sh ]; then
    report_pass "callback-script-present"
else
    report_fail "callback-script-present"
    FAILED=1
fi

if [ -f /etc/sota/conf.d/z-99-aklite-callback.toml ]; then
    report_pass "callback-toml-present"
else
    report_fail "callback-toml-present"
    FAILED=1
fi

if [ -f /var/sota/ota.signal ]; then
    report_pass "ota-signal-present"
else
    report_fail "ota-signal-present"
    FAILED=1
fi

if grep "download-pre" /var/sota/ota.signal; then
    report_pass "download-pre-signal-detected"
else
    report_fail "download-pre-signal-detected"
    FAILED=1
fi

if [ "${FAILED}" -eq 1 ]; then
    echo "Can't run the test, exiting"
    exit 1
fi

FOUND=0

while [ ! "${FOUND}" -eq 1 ]
do
    # sleep 5 min
    echo "Sleeping 5 min"
    date
    sleep 300

    # check if aktualizr-lite log contains timeout
    journalctl --no-pager -u aktualizr-lite
    echo "********************"
    if journalctl --no-pager -u aktualizr-lite | grep "Timeout"; then
        echo "Setting FOUND=1"
        FOUND=1
    fi

done
#check_return "aklite-log-timeout"

exit 0
