#!/bin/bash
#
# usb.sh
#
# Advantech BSP QA – USB host and OTG checks
# Ported from test_usb() in qa/test_board.sh
#
# Copyright (c) 2024 Advantech Co., Ltd. All rights reserved
#

# shellcheck source=../lib/adv-test-lib.sh
. "$(dirname "$0")/../lib/adv-test-lib.sh"

create_out_dir

: "${USB_DEV_COUNT:=0}"
: "${USB_OTG_ENABLED:=0}"
: "${USB_OTG_CONF:=}"

# ─── USB host – any enumerated device ────────────────────────────────────────

if chk_cmd lsusb; then
    dev_count=$(lsusb 2>/dev/null | wc -l)
    if [ "${dev_count}" -gt 0 ]; then
        report_pass "L-USB-HOST-DEV"
    else
        report_fail "L-USB-HOST-DEV"
    fi
else
    report_skip "L-USB-HOST-DEV"
fi

# ─── Specific plugged device checks (functional) ─────────────────────────────

n=0
while [ "${n}" -lt "${USB_DEV_COUNT}" ]; do
    eval "port=\${USB_DEV${n}_PORT}"
    eval "driver=\${USB_DEV${n}_DRIVER}"
    eval "speed=\${USB_DEV${n}_SPEED}"

    req_id="L-USB-PLUGGED-DEV-F-dev${n}"

    if [ -z "${port}" ] || [ -z "${driver}" ] || [ -z "${speed}" ]; then
        report_skip "${req_id}"
        n=$((n + 1))
        continue
    fi

    if chk_cmd lsusb; then
        tspeed=$(lsusb -t 2>/dev/null |
                 grep -E "Port ${port}:|Port 00${port}:" |
                 grep -v root_hub | grep -v "Driver=hub" |
                 grep "If 0" | grep "Driver=${driver}" |
                 grep "${speed}" | awk '{print $NF}')
        if [ "${tspeed}" = "${speed}" ]; then
            report_pass "${req_id}"
        else
            report_fail "${req_id}"
        fi
    else
        report_skip "${req_id}"
    fi

    n=$((n + 1))
done

# ─── USB OTG checks ───────────────────────────────────────────────────────────

if [ "${USB_OTG_ENABLED}" = "1" ] || [ "${USB_OTG_ENABLED}" = "y" ]; then
    # Kernel config checks
    for cfg_key in ${USB_OTG_CONF}; do
        req_id="L-USB-OTG-CONF-${cfg_key}"
        found=0
        if [ -e /proc/config.gz ]; then
            if zcat /proc/config.gz 2>/dev/null | grep -qi "^${cfg_key}=y\|^${cfg_key}=m"; then
                found=1
            fi
        elif [ -e "/boot/config-$(uname -r)" ]; then
            if grep -qi "^${cfg_key}=y\|^${cfg_key}=m" "/boot/config-$(uname -r)" 2>/dev/null; then
                found=1
            fi
        fi
        if [ "${found}" -eq 1 ]; then
            report_pass "${req_id}"
        else
            report_fail "${req_id}"
        fi
    done

    # OTG Ethernet gadget (functional – skip stub; requires physical USB-A→USB-A cable)
    if echo "${USB_OTG_CONF}" | grep -q "CONFIG_USB_ETH"; then
        report_skip "L-USB-OTG-ETH-F"
    fi
fi
