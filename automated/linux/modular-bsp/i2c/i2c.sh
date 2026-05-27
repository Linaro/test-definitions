#!/bin/bash
#
# i2c.sh
#
# Advantech BSP QA – I2C bus checks
# Ported from test_i2c() in qa/test_board.sh
#
# Copyright (c) 2024 Advantech Co., Ltd. All rights reserved
#

# shellcheck source=../lib/adv-test-lib.sh
. "$(dirname "$0")/../lib/adv-test-lib.sh"

create_out_dir

: "${I2C_COUNT:=1}"

n=0
while [ "${n}" -lt "${I2C_COUNT}" ]; do
    eval "dev=\${I2C${n}_DEV}"
    eval "controller=\${I2C${n}_CONTROLLER}"

    iface=$(basename "${dev}")
    req_dev="L-I2C-DEV-i2c${n}"
    req_ctrl="L-I2C-CONTROLLER-i2c${n}"

    # Device node check
    if chk_rw_cdev "${dev}"; then
        report_pass "${req_dev}"
    else
        report_fail "${req_dev}"
        n=$((n + 1))
        continue
    fi

    # Controller name check (requires i2c-tools)
    if [ -n "${controller}" ]; then
        if chk_cmd i2cdetect; then
            if i2cdetect -l 2>/dev/null | grep -w "^${iface}" | grep -q "${controller}"; then
                report_pass "${req_ctrl}"
            else
                report_fail "${req_ctrl}"
            fi
        else
            report_skip "${req_ctrl}"
        fi
    fi

    n=$((n + 1))
done
