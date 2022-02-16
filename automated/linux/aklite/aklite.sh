#!/bin/bash -e
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2021 Foundries.io Ltd.

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
LOGFILE="$(pwd)/aklite.log"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE
DEVICE_NAME=""
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
    error_msg "TARGET variable is missing"
fi

! check_root && error_msg "You need to be root to run this script."
create_out_dir "${OUTPUT}"
aktualizr-lite status > "${LOGFILE}"
if [ -z "${DEVICE_NAME}" ]; then
    warn_msg "DEVICE_NAME empty. Skipping"
    report_skip "aklite-device-name"
else
    # shellcheck disable=SC2086
    if (grep "Device name" $LOGFILE | grep "${DEVICE_NAME}"); then
        report_pass "aklite-device-name"
    else
        report_fail "aklite-device-name"
    fi
    # shellcheck disable=SC2086
    if (grep UUID $LOGFILE); then
        # shellcheck disable=SC2086
        if (grep UUID $LOGFILE | grep Failed); then
            report_fail "aklite-device-registered"
        else
            report_pass "aklite-device-registered"
        fi
    fi
fi

ACTUAL_TARGET=$(aktualizr-lite status | grep "Active image" | xargs echo -n | cut -d " " -f4)
if [ "${ACTUAL_TARGET}" = "${TARGET}" ]; then
    report_pass "aklite-target"
else
    report_fail "aklite-target"
fi
