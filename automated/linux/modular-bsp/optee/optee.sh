#!/bin/bash
#
# optee.sh
#
# Advantech BSP QA – OP-TEE checks
# Ported from test_optee() in qa/test_board.sh
#
# Copyright (c) 2024 Advantech Co., Ltd. All rights reserved
#

# shellcheck source=../lib/adv-test-lib.sh
. "$(dirname "$0")/../lib/adv-test-lib.sh"

create_out_dir

: "${OPTEE_DEV:=/dev/tee0}"
: "${OPTEE_FULL_TEST:=0}"

if [ -n "${OPTEE_DEV}" ]; then
    if chk_rw_cdev "${OPTEE_DEV}"; then
        report_pass "L-OPTEE-DEV"
    else
        report_fail "L-OPTEE-DEV"
        exit 0
    fi
fi

if chk_cmd xtest; then
    if [ "${OPTEE_FULL_TEST}" = "1" ]; then
        xt_args=""
    else
        xt_args="1001"
    fi

    if xtest ${xt_args} >/dev/null 2>&1; then
        report_pass "L-OPTEE-XTEST-F"
    else
        report_fail "L-OPTEE-XTEST-F"
    fi
else
    report_skip "L-OPTEE-XTEST-F"
fi
