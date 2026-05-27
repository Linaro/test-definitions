#!/bin/bash
#
# eth.sh
#
# Advantech BSP QA – Ethernet checks
# Ported from test_eth() in qa/test_board.sh
#
# Copyright (c) 2024 Advantech Co., Ltd. All rights reserved
#

# shellcheck source=../lib/adv-test-lib.sh
. "$(dirname "$0")/../lib/adv-test-lib.sh"

create_out_dir

: "${ETH_COUNT:=1}"
: "${IPERF3_SERVER_IP:=}"
: "${IPERF3_DURATION:=5}"
: "${DNS_CHECK_HOSTS:=advantech.com google.com}"
: "${PING_CHECK_HOSTS:=advantech.com google.com}"

# ─── Per-interface checks ─────────────────────────────────────────────────────

n=0
while [ "${n}" -lt "${ETH_COUNT}" ]; do
    eval "iface=\${ETH${n}_DEV}"
    eval "bus=\${ETH${n}_BUS}"
    eval "bus_id=\${ETH${n}_BUS_ID}"
    eval "link=\${ETH${n}_LINK}"
    eval "wol_feat=\${ETH${n}_WOL_FEATURED}"
    eval "wol_wakeup=\${ETH${n}_WOL_WAKEUP}"
    eval "min_tx=\${ETH${n}_MIN_TX_SPEED:-0}"
    eval "min_rx=\${ETH${n}_MIN_RX_SPEED:-0}"

    label="eth${n}"
    req_dev="L-ETH-DEV-${label}"
    req_ctrl="L-ETH-CONTROLLER-${label}"
    req_link="L-ETH-LINK-${label}"
    req_cfg="L-ETH-CONFIGURED-${label}"
    req_ip4="L-ETH-IPV4-ADDRESS-${label}"
    req_ip6="L-ETH-IPV6-ADDRESS-${label}"
    req_wol_feat="L-ETH-WAKEUP-FEATURED-${label}"
    req_wol_en="L-ETH-WAKEUP-ENABLED-${label}"
    req_tx="L-ETH-TX-THROUGHPUT-F-${label}"
    req_rx="L-ETH-RX-THROUGHPUT-F-${label}"

    # Device existence
    if ip addr show "${iface}" >/dev/null 2>&1; then
        report_pass "${req_dev}"
    else
        report_fail "${req_dev}"
        n=$((n + 1))
        continue
    fi

    # Bus controller
    if [ -n "${bus}" ] && [ -n "${bus_id}" ]; then
        chk_bus "${bus}" "${bus_id}" ethernet net "${iface}" "${req_ctrl}"
    fi

    # Link speed
    if [ -n "${link}" ] && chk_cmd ethtool; then
        la=$(ethtool "${iface}" 2>/dev/null | grep Speed: | awk '{print $2}' | awk -F'M' '{print $1}')
        if [ "${la}" = "${link}" ]; then
            report_pass "${req_link}"
        else
            report_fail "${req_link}"
        fi
    fi

    # Interface UP
    flags=$(ip addr show "${iface}" 2>/dev/null | awk -F'<' '{print $2}' | awk -F'>' '{print $1}' | tr ',' ' ')
    if echo "${flags}" | grep -qw "UP"; then
        report_pass "${req_cfg}"
    else
        report_fail "${req_cfg}"
        n=$((n + 1))
        continue
    fi

    # IPv4 address
    ip4=$(get_ip "${iface}" 4)
    ip4_plain=$(echo "${ip4}" | awk -F/ '{print $1}')
    if [ -n "${ip4}" ]; then
        report_pass "${req_ip4}"
    else
        report_fail "${req_ip4}"
    fi

    # IPv6 address
    ip6=$(get_ip "${iface}" 6)
    if [ -n "${ip6}" ]; then
        report_pass "${req_ip6}"
    else
        report_fail "${req_ip6}"
    fi

    # Wake-on-LAN
    if [ -n "${wol_feat}" ] && chk_cmd ethtool; then
        caps=$(ethtool "${iface}" 2>/dev/null | grep "Supports Wake-on:" | awk '{print $NF}')
        if echo "${caps}" | grep -q "${wol_feat}"; then
            report_pass "${req_wol_feat}"
        else
            report_fail "${req_wol_feat}"
        fi

        if [ -n "${wol_wakeup}" ]; then
            we=$(cat "/sys/class/net/${iface}/device/power/wakeup" 2>/dev/null)
            if [ "${we}" = "${wol_wakeup}" ]; then
                report_pass "${req_wol_en}"
            else
                report_fail "${req_wol_en}"
            fi
        fi
    fi

    # iperf3 throughput (functional – skip when no server IP)
    if [ -z "${IPERF3_SERVER_IP}" ] || [ -z "${ip4_plain}" ]; then
        report_skip "${req_tx}"
        report_skip "${req_rx}"
    else
        if chk_cmd iperf3; then
            # TX
            if [ "${min_tx}" -gt 0 ] 2>/dev/null; then
                tx_raw=$(iperf3 -c "${IPERF3_SERVER_IP}" -B "${ip4_plain}" \
                         -t "${IPERF3_DURATION}" -4 2>/dev/null |
                         grep -i receiver | awk '{print $7}')
                tx_mbps=$(echo "${tx_raw}" | awk '{printf "%d", $1}')
                if [ "${tx_mbps}" -ge "${min_tx}" ] 2>/dev/null; then
                    report_metric "${req_tx}" "pass" "${tx_mbps}" "Mbps"
                else
                    report_metric "${req_tx}" "fail" "${tx_mbps}" "Mbps"
                fi
            else
                report_skip "${req_tx}"
            fi
            # RX
            if [ "${min_rx}" -gt 0 ] 2>/dev/null; then
                rx_raw=$(iperf3 -c "${IPERF3_SERVER_IP}" -B "${ip4_plain}" \
                         -t "${IPERF3_DURATION}" -4 -R 2>/dev/null |
                         grep -i receiver | awk '{print $7}')
                rx_mbps=$(echo "${rx_raw}" | awk '{printf "%d", $1}')
                if [ "${rx_mbps}" -ge "${min_rx}" ] 2>/dev/null; then
                    report_metric "${req_rx}" "pass" "${rx_mbps}" "Mbps"
                else
                    report_metric "${req_rx}" "fail" "${rx_mbps}" "Mbps"
                fi
            else
                report_skip "${req_rx}"
            fi
        else
            report_skip "${req_tx}"
            report_skip "${req_rx}"
        fi
    fi

    n=$((n + 1))
done

# ─── DNS and ping checks ──────────────────────────────────────────────────────

for host in ${DNS_CHECK_HOSTS}; do
    for proto in 4 6; do
        case "${proto}" in
        4) rec=A ;;
        6) rec=AAAA ;;
        esac
        resolved=""
        if chk_cmd host; then
            resolved=$(host -t "${rec}" "${host}" 2>/dev/null | head -1 | awk '{print $NF}')
        else
            resolved=$(ping -c 1 "-${proto}" "${host}" 2>/dev/null | head -1 |
                       awk -F'(' '{print $2}' | awk -F')' '{print $1}')
        fi
        if [ -n "${resolved}" ]; then
            report_pass "L-DNS-IPV${proto}"
        else
            report_fail "L-DNS-IPV${proto}"
        fi
    done
done

for host in ${PING_CHECK_HOSTS}; do
    for proto in 4 6; do
        if ping "-${proto}" -c 1 "${host}" >/dev/null 2>&1; then
            report_pass "L-ETH-IPV${proto}-PING"
        else
            report_fail "L-ETH-IPV${proto}-PING"
        fi
    done
done
