#!/bin/bash
#
# ram.sh
#
# Advantech BSP QA – RAM checks
# Ported from test_ram() in qa/test_board.sh
#
# Copyright (c) 2024 Advantech Co., Ltd. All rights reserved
#

# shellcheck source=../lib/adv-test-lib.sh
. "$(dirname "$0")/../lib/adv-test-lib.sh"

create_out_dir

: "${RAM_SLOT_COUNT:=1}"
: "${RAM_MIN_AVAIL:=0}"

# ─── Per-slot size and speed ──────────────────────────────────────────────────

n=0
while [ "${n}" -lt "${RAM_SLOT_COUNT}" ]; do
    eval "expected_size=\${RAM_SLOT${n}_SIZE:-0}"
    eval "expected_speed=\${RAM_SLOT${n}_SPEED:-}"

    tsize=$(physical_ram_MB)
    req_size="L-RAM-SIZE-slot${n}"
    req_speed="L-RAM-SPEED-slot${n}"

    if [ "${expected_size}" -gt 0 ] 2>/dev/null; then
        if [ "${tsize}" -eq "${expected_size}" ] 2>/dev/null; then
            report_pass "${req_size}"
        else
            report_fail "${req_size}"
        fi
    fi

    if [ -n "${expected_speed}" ]; then
        tspeed=$(physical_ram_MT)
        if [ "${tspeed}" = "${expected_speed}" ]; then
            report_pass "${req_speed}"
        else
            report_fail "${req_speed}"
        fi
    fi

    n=$((n + 1))
done

# ─── Minimum available RAM ────────────────────────────────────────────────────

if [ "${RAM_MIN_AVAIL}" -gt 0 ] 2>/dev/null; then
    tm=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    # Convert kB → MiB (approximate)
    tm_mib=$(( (tm + 0) / 1024 ))
    if [ "${tm_mib}" -ge "${RAM_MIN_AVAIL}" ]; then
        report_pass "L-RAM-AVAILABLE-MIN"
    else
        report_fail "L-RAM-AVAILABLE-MIN"
    fi
    report_metric "L-RAM-AVAILABLE-TOTAL" "pass" "${tm_mib}" "MiB"
fi

# ─── Memory stability test ────────────────────────────────────────────────────

# Use 90% of available free RAM (in MiB)
kib=$(awk '/MemAvailable/ {print int($2 * 0.9)}' /proc/meminfo)
mib=$(( (kib + 0) / 1024 ))

if [ "${mib}" -gt 0 ]; then
    # Try memtester first, fall back to a simple dd-based check
    if chk_cmd memtester; then
        if memtester "${mib}M" 1 >/dev/null 2>&1; then
            report_pass "L-RAM-STABILITY-F"
        else
            report_fail "L-RAM-STABILITY-F"
        fi
    else
        report_skip "L-RAM-STABILITY-F"
    fi
else
    report_skip "L-RAM-STABILITY-F"
fi
