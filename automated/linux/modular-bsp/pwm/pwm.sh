#!/bin/bash
#
# pwm.sh
#
# Advantech BSP QA – PWM checks
# Ported from test_pwm() in qa/test_board.sh
#
# Copyright (c) 2024 Advantech Co., Ltd. All rights reserved
#

# shellcheck source=../lib/adv-test-lib.sh
. "$(dirname "$0")/../lib/adv-test-lib.sh"

create_out_dir

: "${PWM_COUNT:=1}"

n=0
while [ "${n}" -lt "${PWM_COUNT}" ]; do
    eval "dev=\${PWM${n}_DEV}"
    eval "bus=\${PWM${n}_BUS}"
    eval "bus_id=\${PWM${n}_BUS_ID}"

    dpath="/sys/class/pwm/${dev}"
    req_dev="L-PWM-DEV-pwm${n}"
    req_ctrl="L-PWM-CONTROLLER-pwm${n}"

    if [ -e "${dpath}" ]; then
        report_pass "${req_dev}"
    else
        report_fail "${req_dev}"
    fi

    if [ -n "${bus}" ] && [ -n "${bus_id}" ]; then
        chk_bus "${bus}" "${bus_id}" pwm pwm "${dev}" "${req_ctrl}"
    fi

    n=$((n + 1))
done

# Backlight device check
if [ -n "${PWM_BACKLIGHT_DEV}" ]; then
    if [ -e "${PWM_BACKLIGHT_DEV}" ]; then
        report_pass "L-PWM-BACKLIGHT-BRIGHTNESS-DEV"
    else
        report_fail "L-PWM-BACKLIGHT-BRIGHTNESS-DEV"
    fi
fi
