#!/bin/bash
#
# spi.sh
#
# Advantech BSP QA – SPI device checks
# Ported from test_spi() in qa/test_board.sh
#
# Copyright (c) 2024 Advantech Co., Ltd. All rights reserved
#

# shellcheck source=../lib/adv-test-lib.sh
. "$(dirname "$0")/../lib/adv-test-lib.sh"

create_out_dir

: "${SPI_COUNT:=1}"

n=0
while [ "${n}" -lt "${SPI_COUNT}" ]; do
    eval "dev=\${SPI${n}_DEV}"

    req_dev="L-SPI-DEV-spi${n}"
    req_test="L-SPI-DEV-TEST-F-spi${n}"

    if chk_rw_cdev "${dev}"; then
        report_pass "${req_dev}"
    else
        report_fail "${req_dev}"
        n=$((n + 1))
        continue
    fi

    # Functional loopback test – requires physical MOSI-MISO bridge
    if chk_cmd spidev_test; then
        if spidev_test -D "${dev}" >/dev/null 2>&1; then
            report_pass "${req_test}"
        else
            report_fail "${req_test}"
        fi
    else
        report_skip "${req_test}"
    fi

    n=$((n + 1))
done
