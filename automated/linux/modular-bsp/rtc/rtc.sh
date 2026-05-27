#!/bin/bash
#
# rtc.sh
#
# Advantech BSP QA – RTC checks (non-disruptive: device, get/set, wakeup flag)
# The suspend/wakeup test lives in rtc-suspend.sh / a separate LAVA job.
#
# Ported from test_rtc() in qa/test_board.sh
#
# Copyright (c) 2024 Advantech Co., Ltd. All rights reserved
#

# shellcheck source=../lib/adv-test-lib.sh
. "$(dirname "$0")/../lib/adv-test-lib.sh"

create_out_dir

: "${RTC_COUNT:=1}"

# Default /dev/rtc symlink check
if chk_rw_cdev /dev/rtc; then
    report_pass "L-RTC-DEFAULT"
else
    report_fail "L-RTC-DEFAULT"
fi

n=0
while [ "${n}" -lt "${RTC_COUNT}" ]; do
    eval "dev=\${RTC${n}_DEV}"
    eval "wakeup_exp=\${RTC${n}_WAKEUP}"

    iface=$(basename "${dev}")
    req_dev="L-RTC-DEV-rtc${n}"
    req_get="L-RTC-GET-F-rtc${n}"
    req_set="L-RTC-SET-F-rtc${n}"
    req_wakeup="L-RTC-WAKEUP-rtc${n}"

    if chk_rw_cdev "${dev}"; then
        report_pass "${req_dev}"
    else
        report_fail "${req_dev}"
        n=$((n + 1))
        continue
    fi

    # hwclock get
    hwt=$(hwclock --rtc "${dev}" --get 2>/dev/null)
    if [ -n "${hwt}" ]; then
        report_pass "${req_get}"
    else
        report_fail "${req_get}"
        n=$((n + 1))
        continue
    fi

    # hwclock set (round-trip)
    s=$(date -d "${hwt}" +"%Y-%m-%d %H:%M:%S" 2>/dev/null)
    if hwclock --rtc "${dev}" --set --date "${s}" >/dev/null 2>&1; then
        report_pass "${req_set}"
    else
        report_fail "${req_set}"
    fi

    # Wakeup capability
    wu="/sys/class/rtc/${iface}/device/power/wakeup"
    we="disabled"
    [ ! -e "${wu}" ] || we=$(cat "${wu}")

    if [ "${we}" = "${wakeup_exp}" ]; then
        report_pass "${req_wakeup}"
    else
        report_fail "${req_wakeup}"
    fi

    n=$((n + 1))
done
