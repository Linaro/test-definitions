#!/bin/bash
#
# thermal.sh
#
# Advantech BSP QA – Thermal zone checks
# Ported from test_temp() in qa/test_board.sh
#
# Copyright (c) 2024 Advantech Co., Ltd. All rights reserved
#

# shellcheck source=../lib/adv-test-lib.sh
. "$(dirname "$0")/../lib/adv-test-lib.sh"

create_out_dir

: "${THERMAL_COUNT:=1}"

n=0
while [ "${n}" -lt "${THERMAL_COUNT}" ]; do
    eval "dev=\${TZ${n}_DEV}"
    eval "min=\${TZ${n}_MIN:-0}"
    eval "max=\${TZ${n}_MAX:-100}"

    tf="/sys/class/thermal/${dev}/temp"
    req_id="L-THERMAL-ZONE-DEV-tz${n}"

    if [ ! -e "${tf}" ]; then
        report_fail "${req_id}"
        n=$((n + 1))
        continue
    fi
    report_pass "${req_id}"

    raw=$(cat "${tf}" 2>/dev/null)
    temp=$(( (raw + 0) / 1000 ))

    if [ "${temp}" -ge "${min}" ]; then
        report_pass "L-THERMAL-ZONE-MIN-tz${n}"
    else
        report_fail "L-THERMAL-ZONE-MIN-tz${n}"
    fi

    if [ "${temp}" -le "${max}" ]; then
        report_pass "L-THERMAL-ZONE-MAX-tz${n}"
    else
        report_fail "L-THERMAL-ZONE-MAX-tz${n}"
    fi

    report_metric "L-THERMAL-ZONE-TEMP-tz${n}" "pass" "${temp}" "C"

    n=$((n + 1))
done
