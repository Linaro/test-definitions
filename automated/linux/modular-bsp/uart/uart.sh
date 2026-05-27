#!/bin/bash
#
# uart.sh
#
# Advantech BSP QA – UART checks
# Ported from test_uart() in qa/test_board.sh
#
# Copyright (c) 2024 Advantech Co., Ltd. All rights reserved
#

# shellcheck source=../lib/adv-test-lib.sh
. "$(dirname "$0")/../lib/adv-test-lib.sh"

UART_TEST_TIMEOUT_S=1
UART_TEST_LONG_TIMEOUT_S=10

create_out_dir

: "${UART_COUNT:=1}"

n=0
while [ "${n}" -lt "${UART_COUNT}" ]; do
    eval "dev=\${UART${n}_DEV}"
    eval "bus=\${UART${n}_BUS}"
    eval "bus_id=\${UART${n}_BUS_ID}"
    eval "hwfc=\${UART${n}_HWFC:-0}"
    eval "dconsole=\${UART${n}_DEBUG_CONSOLE:-0}"
    eval "lt=\${UART${n}_LOOPBACK_TEST:-skip}"

    label="ser${n}"
    req_dev="L-UART-DEV-${label}"
    req_ctrl="L-UART-CONTROLLER-${label}"
    req_cfg="L-UART-CONFIGURE-F-${label}"
    req_hwfc="L-UART-HWFC-${label}"
    req_lb="L-UART-LOOPBACK-F-${label}"
    req_dbg="L-UART-DEBUG-CONSOLE-${label}"

    # Device node check
    if chk_rw_cdev "${dev}"; then
        report_pass "${req_dev}"
    else
        report_fail "${req_dev}"
        n=$((n + 1))
        continue
    fi

    # Bus controller
    if [ -n "${bus}" ] && [ -n "${bus_id}" ]; then
        chk_bus "${bus}" "${bus_id}" serial tty "${dev}" "${req_ctrl}"
    fi

    # stty configure
    if timeout "${UART_TEST_TIMEOUT_S}" stty -F "${dev}" >/dev/null 2>&1; then
        report_pass "${req_cfg}"
    else
        report_fail "${req_cfg}"
    fi

    # HWFC
    if [ "${hwfc}" = "1" ] || [ "${hwfc}" = "y" ]; then
        if timeout "${UART_TEST_TIMEOUT_S}" stty -F "${dev}" crtscts >/dev/null 2>&1; then
            # Check that crtscts actually appeared in stty output
            if stty -a -F "${dev}" 2>/dev/null | grep -qw "crtscts"; then
                report_pass "${req_hwfc}"
            else
                report_fail "${req_hwfc}"
            fi
        else
            report_fail "${req_hwfc}"
        fi
    else
        report_pass "${req_hwfc}"
    fi

    # Debug console
    if [ "${dconsole}" = "1" ] || [ "${dconsole}" = "y" ]; then
        dc=$(journalctl -b 2>/dev/null | grep command.line |
             grep console= | awk -F'console=' '{print $2}' | awk -F, '{print $1}')
        dt="/dev/${dc}"
        if [ "${dev}" = "${dt}" ]; then
            report_pass "${req_dbg}"
        else
            report_fail "${req_dbg}"
        fi
    else
        report_pass "${req_dbg}"
    fi

    # Loopback tests (functional – skip stubs if lt is "skip" or empty)
    if [ "${lt}" = "skip" ] || [ -z "${lt}" ]; then
        report_skip "${req_lb}"
    else
        cnt=0
        for entry in ${lt}; do
            baud=$(echo "${entry}" | awk -F: '{print $1}')
            wiring=$(echo "${entry}" | awk -F: '{print $2}')
            cnt=$((cnt + 1))
            t="TEST-${cnt}"

            case "${wiring,,}" in
            4w) sf="crtscts" ;;
            2w) sf="-crtscts" ;;
            *)
                warn_msg "UART${n}: invalid wiring '${wiring}' in UART${n}_LOOPBACK_TEST"
                continue
                ;;
            esac

            if ! timeout "${UART_TEST_TIMEOUT_S}" \
                     stty -F "${dev}" "${baud}" ${sf} -cstopb -parenb >/dev/null 2>&1; then
                report_fail "${req_cfg}"
                continue
            fi

            tmpf=$(mktemp /tmp/uart_loopback.XXXXXX)
            timeout "${UART_TEST_LONG_TIMEOUT_S}" head -c "${#t}" < "${dev}" > "${tmpf}" &
            TOUT_PID=$!
            sleep 1
            printf '%s' "${t}" > "${dev}"
            sleep 1
            wait "${TOUT_PID}"
            ec=$?
            t2=$(cat "${tmpf}")
            rm -f "${tmpf}"

            if [ "${ec}" -eq 0 ] && [ "${t}" = "${t2}" ]; then
                report_pass "${req_lb}"
            else
                report_fail "${req_lb}"
            fi
        done
    fi

    n=$((n + 1))
done
