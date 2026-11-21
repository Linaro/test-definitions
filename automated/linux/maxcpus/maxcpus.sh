#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2026 Qualcomm Technologies, Inc. and/or its subsidiaries.
#
# Boot with maxcpus=N: check that exactly N CPUs came up, then bring every
# other present CPU online through hotplug (PSCI CPU_ON for a CPU the
# firmware has never started in this boot) and check that all of them run.
#
# The kernel refuses a late CPU that lacks a capability the boot CPUs
# finalised (e.g. 32-bit EL1 on a big.LITTLE system booted on a little CPU
# with maxcpus=1). That is a kernel policy, not a boot firmware failure, so
# with ALLOW_CAPABILITY_CONFLICT=true such a CPU is reported as skip.

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE

MAXCPUS=""
ALLOW_CAPABILITY_CONFLICT="true"

usage() {
    echo "Usage: $0 [-n <maxcpus>] [-a <true|false>]" 1>&2
    exit 1
}

while getopts "n:a:h" o; do
    case "$o" in
        n) MAXCPUS="${OPTARG}" ;;
        a) ALLOW_CAPABILITY_CONFLICT="${OPTARG}" ;;
        h|*) usage ;;
    esac
done

SYS_CPU=/sys/devices/system/cpu

create_out_dir "${OUTPUT}"

cmdline="$(tr ' ' '\n' < /proc/cmdline | sed -n 's/^maxcpus=//p' | tail -n 1)"
info_msg "kernel command line maxcpus: ${cmdline:-none}"
MAXCPUS="${MAXCPUS:-${cmdline}}"
if [ -z "${MAXCPUS}" ]; then
    info_msg "no maxcpus= on the command line and none given"
    report_skip "maxcpus-cmdline"
    report_skip "maxcpus-online-at-boot"
    report_skip "maxcpus-all-online"
    exit 0
fi
if [ "${cmdline}" = "${MAXCPUS}" ]; then
    report_pass "maxcpus-cmdline"
else
    info_msg "expected maxcpus=${MAXCPUS} on the command line"
    report_fail "maxcpus-cmdline"
fi

online="$(cat ${SYS_CPU}/online)"
present="$(cat ${SYS_CPU}/present)"
info_msg "at boot: online ${online}, present ${present}"
n_online="$(cpu_list_count "${online}")"
# A CPU the kernel refuses also leaves the present mask, so keep the count
# from before hotplug.
n_present="$(cpu_list_count "${present}")"
if [ "${n_online}" -eq "${MAXCPUS}" ]; then
    add_metric "maxcpus-online-at-boot" "pass" "${n_online}" "cpus"
else
    add_metric "maxcpus-online-at-boot" "fail" "${n_online}" "cpus"
fi

refused=0
failed=0
for n in $(cpu_list_expand "${present}"); do
    c="${SYS_CPU}/cpu${n}"
    [ -f "${c}/online" ] || continue
    [ "$(cat "${c}/online")" = 1 ] && continue
    if echo 1 > "${c}/online" && [ "$(cat "${c}/online")" = 1 ]; then
        report_pass "cpu${n}-online"
        continue
    fi
    dmesg | grep -E "CPU${n}: (Detected conflict|will not boot|failed to come online|died)" | tail -n 3
    if dmesg | grep -q "CPU features: CPU${n}: Detected conflict for capability" &&
       { [ "${ALLOW_CAPABILITY_CONFLICT}" = "true" ] || [ "${ALLOW_CAPABILITY_CONFLICT}" = "True" ]; }; then
        info_msg "cpu${n} refused by the kernel capability check"
        report_skip "cpu${n}-online"
        refused=$((refused + 1))
    else
        report_fail "cpu${n}-online"
        failed=$((failed + 1))
    fi
done

online="$(cat ${SYS_CPU}/online)"
info_msg "after hotplug: online ${online}, present $(cat ${SYS_CPU}/present), ${refused} refused, ${failed} failed"
if [ "${failed}" -eq 0 ] && [ "$(cpu_list_count "${online}")" -eq $((n_present - refused)) ]; then
    add_metric "maxcpus-all-online" "pass" "$(cpu_list_count "${online}")" "cpus"
else
    add_metric "maxcpus-all-online" "fail" "$(cpu_list_count "${online}")" "cpus"
fi
exit 0
