#!/bin/bash
#
# npu.sh
#
# Advantech BSP QA – NPU device checks
# Ported from test_npu() in qa/test_board.sh
#
# Copyright (c) 2024 Advantech Co., Ltd. All rights reserved
#

# shellcheck source=../lib/adv-test-lib.sh
. "$(dirname "$0")/../lib/adv-test-lib.sh"

create_out_dir

: "${NPU_COUNT:=1}"

n=0
while [ "${n}" -lt "${NPU_COUNT}" ]; do
    eval "dev=\${NPU${n}_DEV}"
    eval "bus=\${NPU${n}_BUS}"
    eval "bus_id=\${NPU${n}_BUS_ID}"
    eval "bus_dt=\${NPU${n}_BUS_DEVICE_TYPE}"
    eval "bus_nn=\${NPU${n}_BUS_NODE_NAME}"

    req_dev="L-NPU-DEV-npu${n}"
    req_ctrl="L-NPU-CONTROLLER-npu${n}"

    if [ -n "${dev}" ]; then
        if chk_rw_cdev "${dev}"; then
            report_pass "${req_dev}"
        else
            report_fail "${req_dev}"
        fi
    fi

    if [ -n "${bus}" ] && [ -n "${bus_id}" ]; then
        chk_bus "${bus}" "${bus_id}" "${bus_dt}" "${bus_nn}" "${dev}" "${req_ctrl}"
    fi

    n=$((n + 1))
done
