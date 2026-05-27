#!/bin/bash
#
# watchdog.sh
#
# Advantech BSP QA – Watchdog non-disruptive checks (device + service)
# Ported from test_watchdog() in qa/test_board.sh
#
# Copyright (c) 2024 Advantech Co., Ltd. All rights reserved
#

# shellcheck source=../lib/adv-test-lib.sh
. "$(dirname "$0")/../lib/adv-test-lib.sh"

create_out_dir

: "${WATCHDOG_COUNT:=1}"

n=0
while [ "${n}" -lt "${WATCHDOG_COUNT}" ]; do
    eval "dev=\${WATCHDOG${n}_DEV}"

    if chk_rw_cdev "${dev}"; then
        report_pass "L-WATCHDOG-DEV-watchdog${n}"
    else
        report_fail "L-WATCHDOG-DEV-watchdog${n}"
    fi

    n=$((n + 1))
done

# Watchdog daemon running
if pgrep watchdog >/dev/null 2>&1; then
    report_pass "L-WATCHDOG-SERVICE"
else
    report_fail "L-WATCHDOG-SERVICE"
fi
