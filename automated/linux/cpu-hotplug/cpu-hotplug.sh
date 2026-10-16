#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2026 Qualcomm Technologies, Inc. and/or its subsidiaries.
#
# CPU hotplug through the firmware (PSCI CPU_OFF and CPU_ON).
#
# Rounds: each hotpluggable CPU goes offline and back online ROUNDS times,
# idle and then under stress-ng load on the other CPUs, then all of them go
# offline together and come back.
#
# Race: one loop per hotpluggable CPU, all in parallel under stress-ng load
# for RACE_SECONDS, takes its CPU offline and at once back online, so that
# CPU_ON reaches the firmware as soon as PSCI AFFINITY_INFO reports the CPU
# off, while other CPUs go off and on around it.
#
# A sysfs write that does not return within TIMEOUT seconds (a CPU_ON or
# CPU_OFF that never completes), a CPU that does not come back, an online
# mask that is not restored, or a PSCI error, warning or oops in the kernel
# log is a failure.

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE

ROUNDS=5
RACE_SECONDS=300
TIMEOUT=20
IGNORE=""

usage() {
    echo "Usage: $0 [-r <rounds>] [-s <race seconds>] [-t <timeout>] [-i <ignore regex>]" 1>&2
    exit 1
}

while getopts "r:s:t:i:h" o; do
    case "$o" in
        r) ROUNDS="${OPTARG}" ;;
        s) RACE_SECONDS="${OPTARG}" ;;
        t) TIMEOUT="${OPTARG}" ;;
        i) IGNORE="${OPTARG}" ;;
        h|*) usage ;;
    esac
done

SYS_CPU=/sys/devices/system/cpu

create_out_dir "${OUTPUT}"

# CPUs with an online control that are online now.
cpus=""
for d in "${SYS_CPU}"/cpu[0-9]*; do
    [ -w "${d}/online" ] || continue
    [ "$(cat "${d}/online")" = 1 ] || continue
    cpus="${cpus} ${d##*cpu}"
done
cpus="${cpus# }"
before="$(cat "${SYS_CPU}/online")"
info_msg "online CPUs: ${before}; hotpluggable:${cpus:- none}"
if [ -z "${cpus}" ]; then
    report_skip "hotplug-all-together"
    report_skip "hotplug-race"
    exit 0
fi

# set_online <cpu> <0|1>: write the online control in the background and
# fail if it has not returned within TIMEOUT seconds.
set_online() {
    (echo "$2" > "${SYS_CPU}/cpu$1/online") 2>/dev/null &
    w=$!
    t=0
    while kill -0 "${w}" 2>/dev/null; do
        sleep 1
        t=$((t + 1))
        if [ "${t}" -ge "${TIMEOUT}" ]; then
            kill -9 "${w}" 2>/dev/null
            warn_msg "cpu$1: writing $2 to online did not return in ${TIMEOUT} s"
            return 1
        fi
    done
    wait "${w}" && [ "$(cat "${SYS_CPU}/cpu$1/online")" = "$2" ]
}

# cycle <cpu>: offline then at once online, both writes in one background
# job so that nothing runs between the return of the offline and the online.
cycle() {
    (echo 0 > "${SYS_CPU}/cpu$1/online" && echo 1 > "${SYS_CPU}/cpu$1/online") 2>/dev/null &
    w=$!
    t=0
    while kill -0 "${w}" 2>/dev/null; do
        sleep 1
        t=$((t + 1))
        if [ "${t}" -ge $((2 * TIMEOUT)) ]; then
            kill -9 "${w}" 2>/dev/null
            return 1
        fi
    done
    wait "${w}" && [ "$(cat "${SYS_CPU}/cpu$1/online")" = 1 ]
}

load_start() {
    load_pid=""
    if command -v stress-ng > /dev/null 2>&1; then
        stress-ng --cpu 0 --timeout "$1" > /dev/null 2>&1 &
        load_pid=$!
    else
        warn_msg "stress-ng not found: running without load"
    fi
}

load_stop() {
    [ -z "${load_pid}" ] || { kill "${load_pid}" 2>/dev/null; wait "${load_pid}" 2>/dev/null; }
}

check_mask() {
    after="$(cat "${SYS_CPU}/online")"
    info_msg "online CPUs before ${before}, after ${after}"
    if [ "${after}" = "${before}" ]; then
        report_pass "$1"
    else
        report_fail "$1"
        for c in ${cpus}; do
            echo 1 > "${SYS_CPU}/cpu${c}/online" 2>/dev/null
        done
    fi
}

# The kernel log from here on is this test's. The races print more than
# the log buffer holds, so the log is streamed from /dev/kmsg for the whole
# test and kept from a marker on (log timestamps stop during suspend,
# /proc/uptime does not); the buffer is left intact for later tests.
# Without the marker, or once it has left the buffer, the whole log is
# checked.
marker="cpu-hotplug: start $$"
echo "${marker}" 2>/dev/null > /dev/kmsg || marker=""
kmsg_pid=""
if [ -r /dev/kmsg ]; then
    cat /dev/kmsg > "${OUTPUT}/kmsg.txt" 2>/dev/null &
    kmsg_pid=$!
fi

for load in idle load; do
    [ "${load}" = load ] && load_start 3600
    for c in ${cpus}; do
        result=pass
        r=1
        while [ "${r}" -le "${ROUNDS}" ]; do
            if ! set_online "${c}" 0 || ! set_online "${c}" 1; then
                warn_msg "cpu${c}: ${load} round ${r} failed"
                set_online "${c}" 1
                result=fail
                break
            fi
            r=$((r + 1))
        done
        "report_${result}" "hotplug-${load}-cpu${c}"
    done
    [ "${load}" = load ] && load_stop
done

# All together, but one CPU stays online: where every CPU is hotpluggable
# (cpu0 included), the first one in the list. The races run on the same
# CPUs, since the last online CPU refuses to go offline.
together="${cpus}"
online_count="$(cpu_list_count "${before}")"
# shellcheck disable=SC2086
if [ "$(set -- ${cpus}; echo $#)" -ge "${online_count}" ]; then
    case "${cpus}" in
        *" "*) together="${cpus#* }" ;;
        *) together="" ;;
    esac
fi
result=pass
for c in ${together}; do
    set_online "${c}" 0 || result=fail
done
for c in ${together}; do
    set_online "${c}" 1 || result=fail
done
"report_${result}" "hotplug-all-together"
check_mask "hotplug-online-mask-restored"

if [ "${RACE_SECONDS}" -gt 0 ]; then
    load_start $((RACE_SECONDS + 120))
    end=$(( $(date +%s) + RACE_SECONDS ))
    pids=""
    for c in ${together}; do
        (
            n=0
            f=0
            while [ "$(date +%s)" -lt "${end}" ]; do
                if cycle "${c}"; then
                    n=$((n + 1))
                else
                    f=$((f + 1))
                    warn_msg "cpu${c}: race cycle ${n} failed"
                    set_online "${c}" 1 || break
                fi
            done
            echo "${n} ${f}" > "${OUTPUT}/race-cpu${c}"
        ) &
        pids="${pids} $!"
    done
    for p in ${pids}; do
        wait "${p}"
    done
    load_stop
    total=0
    for c in ${together}; do
        # shellcheck disable=SC2046
        set -- $(cat "${OUTPUT}/race-cpu${c}" 2>/dev/null || echo "0 1")
        total=$((total + $1))
        info_msg "cpu${c}: ${1} race cycles, ${2} failed"
        if [ "$2" = 0 ] && [ "$1" -gt 0 ]; then
            add_metric "race-cpu${c}" pass "$1" cycles
        else
            add_metric "race-cpu${c}" fail "$1" cycles
        fi
    done
    add_metric "race-total-cycles" pass "${total}" cycles
    check_mask "race-online-mask-restored"
else
    report_skip "hotplug-race"
fi

pattern='failed to come online|CPU[0-9]+: failed|psci: .*(fail|error)|Kernel panic|BUG:|WARNING:|Internal error|hung_task'
# /dev/kmsg records are "<prio>,<seq>,<usec>,<flags>;<message>".
if [ -n "${kmsg_pid}" ] && kill -0 "${kmsg_pid}" 2>/dev/null; then
    kill "${kmsg_pid}"
    wait "${kmsg_pid}" 2>/dev/null
    awk -v m="${marker}" 'BEGIN { f = (m == "") } index($0, ";") {
        msg = substr($0, index($0, ";") + 1)
        if (f) print msg
        if (m != "" && msg == m) f = 1 }' \
        "${OUTPUT}/kmsg.txt" > "${OUTPUT}/dmesg-test.txt"
elif dmesg > "${OUTPUT}/dmesg.txt" 2>/dev/null; then
    warn_msg "the kernel log was not streamed: lines pushed out of the log buffer are not checked"
    awk -v m="${marker}" 'f { print; next } { b[++n] = $0 } m != "" && substr($0, length($0) - length(m) + 1) == m { f = 1 } END { if (!f) for (i = 1; i <= n; i++) print b[i] }' \
        "${OUTPUT}/dmesg.txt" > "${OUTPUT}/dmesg-test.txt"
else
    warn_msg "cannot read the kernel log"
    report_skip "hotplug-kernel-clean"
    exit 0
fi
info_msg "$(wc -l < "${OUTPUT}/dmesg-test.txt") kernel log lines during the test"
grep -i -E 'psci|cpu[0-9]+: (shutdown|killed|failed)|Kernel panic|BUG:|WARNING:|Internal error|hung_task' "${OUTPUT}/dmesg-test.txt" | tail -n 40
if [ -n "${IGNORE}" ]; then
    grep -i -E "${pattern}" "${OUTPUT}/dmesg-test.txt" | grep -v -E "${IGNORE}" > "${OUTPUT}/issues.txt"
else
    grep -i -E "${pattern}" "${OUTPUT}/dmesg-test.txt" > "${OUTPUT}/issues.txt"
fi
bad="$(wc -l < "${OUTPUT}/issues.txt")"
if [ "${bad}" = 0 ]; then
    report_pass "hotplug-kernel-clean"
else
    add_metric "hotplug-kernel-clean" "fail" "${bad}" "lines"
fi
exit 0
