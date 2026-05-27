#!/bin/bash
#
# cpu.sh
#
# Advantech BSP QA – CPU checks
# Ported from test_cpu() in qa/test_board.sh
#
# Copyright (c) 2024 Advantech Co., Ltd. All rights reserved
#

# shellcheck source=../lib/adv-test-lib.sh
. "$(dirname "$0")/../lib/adv-test-lib.sh"

create_out_dir

: "${CPU_NPROC:=}"
: "${CPU_CSTATES:=}"
: "${CPU_SCALING_MIN:=0}"
: "${CPU_SCALING_MAX:=0}"
: "${CPU_SCALING_GOVERNORS:=}"
: "${CPU_SUSPENSION_STATES:=}"

np=$(nproc)
tnp=0
tnp_max=0

# CPU_NPROC may be a space-separated list of acceptable counts, e.g. "2 4"
for j in ${CPU_NPROC}; do
    i=$(echo "${j}" | awk -F: '{print $1+0}')
    [ "${np}" -eq "${i}" ] && tnp=${i}
    [ "${tnp_max}" -lt "${i}" ] && tnp_max=${i}
done

if [ -n "${CPU_NPROC}" ]; then
    if [ "${tnp}" -eq "${np}" ]; then
        report_pass "L-CPU-NPROC"
    else
        report_fail "L-CPU-NPROC"
    fi
fi

# Per-core checks
n=0
while [ "${n}" -lt "${tnp_max}" ]; do
    k="cpu${n}"
    cn="/sys/devices/system/cpu/${k}"
    cpufreq="${cn}/cpufreq"

    if [ "${n}" -ge "${tnp}" ]; then
        # Core not present in this variant
        report_skip "L-CPU-C-STATES-${k}"
        report_skip "L-CPU-FREQ-SCALING-MIN-${k}"
        report_skip "L-CPU-FREQ-SCALING-MAX-${k}"
        report_skip "L-CPU-SCALING-GOVERNOR-${k}"
        report_skip "L-CPU-SCALING-GOVERNOR-SET-F-${k}"
        n=$((n + 1))
        continue
    fi

    # C-state check
    for cs in ${CPU_CSTATES}; do
        cstate_files="${cn}/cpuidle/state*/name"
        # allow glob to expand; if none match grep does not find it
        if grep -q "${cs}" ${cstate_files} /dev/null 2>/dev/null; then
            report_pass "L-CPU-C-STATES-${k}"
        else
            report_fail "L-CPU-C-STATES-${k}"
        fi
    done

    [ -e "${cpufreq}" ] || { n=$((n + 1)); continue; }

    # Scaling min freq
    if [ "${CPU_SCALING_MIN}" -gt 0 ] 2>/dev/null; then
        ft=$(cat "${cpufreq}/scaling_min_freq" 2>/dev/null)
        ft=$((ft + 0))
        if [ "${CPU_SCALING_MIN}" -eq "${ft}" ]; then
            report_pass "L-CPU-FREQ-SCALING-MIN-${k}"
        else
            report_fail "L-CPU-FREQ-SCALING-MIN-${k}"
        fi
    fi

    # Scaling max freq
    if [ "${CPU_SCALING_MAX}" -gt 0 ] 2>/dev/null; then
        ft=$(cat "${cpufreq}/scaling_max_freq" 2>/dev/null)
        ft=$((ft + 0))
        if [ "${CPU_SCALING_MAX}" -eq "${ft}" ]; then
            report_pass "L-CPU-FREQ-SCALING-MAX-${k}"
        else
            report_fail "L-CPU-FREQ-SCALING-MAX-${k}"
        fi
    fi

    # Scaling governors
    prev_gov=$(cat "${cpufreq}/scaling_governor" 2>/dev/null)
    avail_gov="${cpufreq}/scaling_available_governors"

    for gov in ${CPU_SCALING_GOVERNORS}; do
        found_gov=$(xargs -n1 < "${avail_gov}" 2>/dev/null | grep -w "${gov}" | head -1)
        if [ "${found_gov}" = "${gov}" ]; then
            report_pass "L-CPU-SCALING-GOVERNOR-${k}"
        else
            report_fail "L-CPU-SCALING-GOVERNOR-${k}"
            continue
        fi

        # Functional: set governor (requires cpufreq-set)
        if chk_cmd cpufreq-set && \
           [ "${CPU_SCALING_MIN}" -gt 0 ] && [ "${CPU_SCALING_MAX}" -gt 0 ] 2>/dev/null; then
            if cpufreq-set -c "${n}" -r -g "${gov}" \
                    --min "${CPU_SCALING_MIN}" \
                    --max "${CPU_SCALING_MAX}" 2>/dev/null; then
                report_pass "L-CPU-SCALING-GOVERNOR-SET-F-${k}"
                # Restore
                cpufreq-set -c "${n}" -r -g "${prev_gov}" \
                    --min "${CPU_SCALING_MIN}" \
                    --max "${CPU_SCALING_MAX}" 2>/dev/null || true
            else
                report_fail "L-CPU-SCALING-GOVERNOR-SET-F-${k}"
            fi
        else
            report_skip "L-CPU-SCALING-GOVERNOR-SET-F-${k}"
        fi
    done

    n=$((n + 1))
done

# Power suspension states
for ps in ${CPU_SUSPENSION_STATES}; do
    found=$(xargs -n1 < /sys/power/state 2>/dev/null | grep -w "${ps}" | head -1)
    if [ "${found}" = "${ps}" ]; then
        report_pass "L-CPU-POWER-STATE-SUSPENSION"
    else
        report_fail "L-CPU-POWER-STATE-SUSPENSION"
    fi
done
