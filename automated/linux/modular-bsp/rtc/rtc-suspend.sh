#!/bin/bash
#
# rtc-suspend.sh
#
# Advantech BSP QA – RTC suspend/wakeup test (separate LAVA job)
# Ported from the suspend/wakeup block in test_rtc() in qa/test_board.sh
#
# Copyright (c) 2024 Advantech Co., Ltd. All rights reserved
#

# shellcheck source=../lib/adv-test-lib.sh
. "$(dirname "$0")/../lib/adv-test-lib.sh"

create_out_dir

: "${RTC_DEV:=/dev/rtc0}"
: "${SLEEP_STATE:=mem}"
: "${WAKE_SLEEP_TIME_S:=5}"

req_id="L-SUSPEND-WAKEUP-F-rtc0"

if ! [ -e "${RTC_DEV}" ]; then
    report_skip "${req_id}"
    exit 0
fi

ts0=$(date +%s)
if rtcwake -m "${SLEEP_STATE}" -s "${WAKE_SLEEP_TIME_S}" -d "${RTC_DEV}" >/dev/null 2>&1; then
    tdiff=$(( $(date +%s) - ts0 + 1 ))
    if [ "${tdiff}" -ge "${WAKE_SLEEP_TIME_S}" ]; then
        report_metric "${req_id}" "pass" "${tdiff}" "s"
    else
        report_metric "${req_id}" "fail" "${tdiff}" "s"
    fi
else
    report_fail "${req_id}"
fi
