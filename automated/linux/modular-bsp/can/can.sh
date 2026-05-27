#!/bin/bash
#
# can.sh
#
# Advantech BSP QA – CAN bus checks
# Ported from test_can() / can_p2p_aux() in qa/test_board.sh
#
# Copyright (c) 2024 Advantech Co., Ltd. All rights reserved
#

# shellcheck source=../lib/adv-test-lib.sh
. "$(dirname "$0")/../lib/adv-test-lib.sh"

CAN_TEST_TIMEOUT_S=2

create_out_dir

: "${CAN_COUNT:=1}"
: "${CAN_EXT_LOOPBACK:=}"

# ─── Helper: run a CAN loopback test ─────────────────────────────────────────
# can_loopback_test <src> <tgt> <bitrate> <type: loopback|p2p> <req_id>
can_loopback_test() {
    local src="$1" tgt="$2" bitrate="$3" type="$4" req_id="$5"
    local frame="123#CAFE01EDECAF"
    local tmpf
    tmpf=$(mktemp /tmp/can_test.XXXXXX)
    local lb_params ifs

    case "${type}" in
    loopback) lb_params="loopback on";  ifs="${src}" ;;
    p2p)      lb_params="loopback off"; ifs="${src} ${tgt}" ;;
    *)
        report_fail "${req_id}"
        rm -f "${tmpf}"
        return 1
        ;;
    esac

    local ok=1
    for iface in ${ifs}; do
        ip link set "${iface}" down 2>/dev/null
        if ! ip link set "${iface}" type can bitrate "${bitrate}" ${lb_params} 2>/dev/null; then
            ok=0; break
        fi
        if ! ip link set "${iface}" up 2>/dev/null; then
            ok=0; break
        fi
    done

    if [ "${ok}" -eq 1 ]; then
        local tout_ms=$(( CAN_TEST_TIMEOUT_S * 1000 ))
        candump "${tgt}" -T "${tout_ms}" -n 1 >"${tmpf}" 2>/dev/null &
        CANDUMP_PID=$!
        sleep 1
        if cansend "${src}" "${frame}" >/dev/null 2>&1; then
            wait "${CANDUMP_PID}"
            r=$(cat "${tmpf}")
            header=$(awk '{print $2}' <<< "${r}")
            data=$(awk -F] '{print $2}' <<< "${r}")
            f2=$(echo "${header}#${data}" | sed 's/ //g')
            [ "${f2}" = "${frame}" ] && ok=1 || ok=0
        else
            ok=0
            wait "${CANDUMP_PID}" 2>/dev/null || true
        fi
    fi

    # Cleanup
    for iface in ${ifs}; do
        ip link set "${iface}" down 2>/dev/null
        ip link set "${iface}" type can bitrate "${bitrate}" loopback off 2>/dev/null || true
    done
    rm -f "${tmpf}"

    if [ "${ok}" -eq 1 ]; then
        report_pass "${req_id}"
    else
        report_fail "${req_id}"
    fi
}

# ─── Per-interface checks ─────────────────────────────────────────────────────

n=0
while [ "${n}" -lt "${CAN_COUNT}" ]; do
    eval "iface=\${CAN${n}_DEV}"
    eval "bus=\${CAN${n}_BUS}"
    eval "bus_id=\${CAN${n}_BUS_ID}"
    eval "clock=\${CAN${n}_CLOCK}"
    eval "lb_speeds=\${CAN${n}_LOOPBACK_SPEEDS}"

    label="can${n}"
    req_dev="L-CAN-DEV-${label}"
    req_clock="L-CAN-CLOCK-${label}"
    req_ctrl="L-CAN-CONTROLLER-${label}"
    req_lb="L-CAN-LOOPBACK-F-${label}"

    # Interface existence
    if ip addr show "${iface}" >/dev/null 2>&1; then
        report_pass "${req_dev}"
    else
        report_fail "${req_dev}"
        n=$((n + 1))
        continue
    fi

    # Clock frequency
    if [ -n "${clock}" ]; then
        cfound=$(ip -details -json link show "${iface}" 2>/dev/null |
                 grep '"clock":' | awk -F'"clock":' '{print $2}' | awk -F'}' '{print $1}' |
                 xargs)
        if [ "${cfound}" = "${clock}" ]; then
            report_pass "${req_clock}"
        else
            report_fail "${req_clock}"
        fi
    fi

    # Bus controller
    if [ -n "${bus}" ] && [ -n "${bus_id}" ]; then
        chk_bus "${bus}" "${bus_id}" can net "${iface}" "${req_ctrl}"
    fi

    # Software loopback tests
    for bitrate in ${lb_speeds}; do
        can_loopback_test "${iface}" "${iface}" "${bitrate}" loopback "${req_lb}"
    done

    n=$((n + 1))
done

# ─── External (p2p) loopback tests ───────────────────────────────────────────

if [ -z "${CAN_EXT_LOOPBACK}" ]; then
    report_skip "L-CAN-EXT-LOOP-F"
else
    for entry in ${CAN_EXT_LOOPBACK}; do
        ifA=$(echo "${entry}" | awk -F: '{print $1}')
        ifB=$(echo "${entry}" | awk -F: '{print $2}')
        bitrate=$(echo "${entry}" | awk -F: '{print $3}')
        can_loopback_test "${ifA}" "${ifB}" "${bitrate}" p2p "L-CAN-EXT-LOOP-F"
    done
fi
