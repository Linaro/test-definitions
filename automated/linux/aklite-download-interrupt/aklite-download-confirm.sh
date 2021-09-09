#!/bin/bash -e
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2021 Foundries.io Ltd.

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE

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

if [ ! "${FAILED}" -eq 0 ]; then
    report_skip "install-pre-received"
    exit "${FAILED}"
fi

# wait for 'install-pre' signal
SIGNAL=$(</var/sota/ota.signal)
while [ ! "${SIGNAL}" = "install-pre" ]
do
	echo "Sleeping 1s"
	sleep 1
	cat /var/sota/ota.signal
	SIGNAL=$(</var/sota/ota.signal)
	echo "SIGNAL: ${SIGNAL}."
done
report_pass "install-pre-received"
# board should reboot shortly after
exit 0
