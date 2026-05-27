#!/bin/bash
#
# context.sh
#
# Advantech BSP QA – Context checks
# Ported from test_context() in qa/test_board.sh
#
# Copyright (c) 2024 Advantech Co., Ltd. All rights reserved
#

# shellcheck source=../lib/adv-test-lib.sh
. "$(dirname "$0")/../lib/adv-test-lib.sh"

create_out_dir

# ─── Distro ID ───────────────────────────────────────────────────────────────

if [ -n "${DISTRO_ID}" ]; then
    dt=$(get_distro_id)
    if echo "${dt}" | grep -qi "${DISTRO_ID}"; then
        report_pass "L-SW-DISTRO-ID"
    else
        report_fail "L-SW-DISTRO-ID"
    fi
fi

# ─── Distro version ──────────────────────────────────────────────────────────

if [ -n "${DISTRO_VER}" ]; then
    vt=$(get_distro_ver)
    if echo "${vt}" | grep -qi "${DISTRO_VER}"; then
        report_pass "L-SW-DISTRO-VER"
    else
        report_fail "L-SW-DISTRO-VER"
    fi
fi

# ─── Kernel minimum version ──────────────────────────────────────────────────

if [ -n "${KERNEL_MIN_VER}" ]; then
    req_major=$(echo "${KERNEL_MIN_VER}" | awk -F. '{print $1+0}')
    req_minor=$(echo "${KERNEL_MIN_VER}" | awk -F. '{print $2+0}')
    cur=$(uname -r)
    cur_major=$(echo "${cur}" | awk -F. '{print $1+0}')
    cur_minor=$(echo "${cur}" | awk -F. '{print $2+0}')

    if [ "${cur_major}" -gt "${req_major}" ] || \
       { [ "${cur_major}" -eq "${req_major}" ] && [ "${cur_minor}" -ge "${req_minor}" ]; }; then
        report_pass "L-SW-KERNEL-MIN-VER"
    else
        report_fail "L-SW-KERNEL-MIN-VER"
    fi
fi

# ─── CPU model ───────────────────────────────────────────────────────────────

if [ -n "${CPU_MODEL}" ]; then
    cpu_model=$(grep -m1 'Model name\|Hardware\|cpu model' /proc/cpuinfo 2>/dev/null |
                awk -F: '{print $2}' | xargs)
    if echo "${cpu_model}" | grep -qi "${CPU_MODEL}"; then
        report_pass "L-CPU-MODEL"
    else
        report_fail "L-CPU-MODEL"
    fi
fi

# ─── BIOS date ───────────────────────────────────────────────────────────────

if [ -n "${BIOS_DATE}" ]; then
    bios_raw=$(cat /sys/class/dmi/id/bios_date 2>/dev/null || dmidecode -s bios-release-date 2>/dev/null)
    # Normalise MM/DD/YYYY → YYYYMMDD
    bios_norm=$(echo "${bios_raw}" |
                awk -F/ 'NF==3{printf "%04d%02d%02d\n",$3,$1,$2} NF!=3{print $0}')
    if [ "${bios_norm}" = "${BIOS_DATE}" ]; then
        report_pass "L-BIOS-DATE-MINIMUM"
    else
        report_fail "L-BIOS-DATE-MINIMUM"
    fi
fi
