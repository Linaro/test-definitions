#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2026 Qualcomm Technologies, Inc. and/or its subsidiaries.
#
# remoteproc smoke tests
#
# Check that the remoteprocs which the kernel is expected to boot are running,
# to catch regressions where a DSP silently fails to come up, e.g. because its
# firmware could not be loaded, and that none of them has crashed since boot:
# a remoteproc that crashes and is recovered is running again by the time
# its state is read.
#
# With ITERATIONS above 0, each tested remoteproc is then stopped and started
# through sysfs ITERATIONS times: the state must read offline after the stop
# and running after the start, the rpmsg devices the remoteproc had before the
# first stop must come back bound to the same drivers, and the kernel must log
# no remoteproc crash, warning or oops meanwhile. Every step is a test case per
# remoteproc and iteration. EXPECTED_FAIL lists remoteprocs known not to
# survive a restart, as <name>=<reason> separated by ';': they are reported as
# skip with the reason and not restarted, since a failed restart can take the
# kernel down with it.

# shellcheck disable=SC1091,SC2034,SC2039
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE
SYSFS_REMOTEPROC="/sys/class/remoteproc"
DEVICE=""
# remoteprocs which the kernel doesn't boot on its own, either because no
# firmware is shipped for them or because another subsystem owns their
# lifecycle, e.g. ath11k for wpss; see
# https://github.com/qualcomm/fastrpc/pull/372
SKIP="modem wpss"
WAIT_TIME=0
SYSFS_RPMSG="/sys/bus/rpmsg/devices"
ITERATIONS=0
EXPECTED_FAIL=""
RESTART_TIMEOUT=30
SETTLE_TIME=5
STEPS="stop offline start running channels kernel-clean"
ISSUES="crash detected|fatal error received|watchdog received|WARNING:|BUG:|Oops|Internal error|Unable to handle|Call trace:|Kernel panic|external abort|blocked for more than"

usage() {
    echo "Usage: $0 [-d <remoteprocs>] [-s <remoteprocs>] [-w <wait_time>]" 1>&2
    echo "          [-n <iterations>] [-x '<remoteproc>=<reason>;...']" 1>&2
    echo "          [-t <restart_timeout>] [-e <settle_time>]" 1>&2
    exit 1
}

while getopts "d:s:w:n:x:t:e:" o; do
  case "$o" in
    d) DEVICE="${OPTARG}" ;;
    s) SKIP="${OPTARG}" ;;
    w) WAIT_TIME="${OPTARG}" ;;
    n) ITERATIONS="${OPTARG}" ;;
    x) EXPECTED_FAIL="${OPTARG}" ;;
    t) RESTART_TIMEOUT="${OPTARG}" ;;
    e) SETTLE_TIME="${OPTARG}" ;;
    *) usage ;;
  esac
done

# list the sysfs directories of all remoteprocs, one per line
list_remoteprocs() {
    for dir in "${SYSFS_REMOTEPROC}"/remoteproc*; do
        [ -r "${dir}/name" ] || continue
        echo "${dir}"
    done
}

# list the sysfs directories of the remoteprocs named $1, one per line; a name
# is not guaranteed to be unique, e.g. some SoCs have two cdsp instances
remoteprocs_by_name() {
    local name="$1"
    for dir in $(list_remoteprocs); do
        [ "$(cat "${dir}/name")" = "${name}" ] && echo "${dir}"
    done
    return 0
}

# print a stable identifier for the remoteproc in sysfs directory $1; the
# remoteprocN index is assigned in probe order and may change across boots, so
# derive the identifier from the underlying platform device instead
remoteproc_id() {
    basename "$(readlink -f "$1/device")"
}

# whether remoteproc $1 is expected not to be running
is_skipped() {
    local name="$1"
    for skipped in ${SKIP}; do
        [ "${name}" = "${skipped}" ] && return 0
    done
    return 1
}

# print the test case name for the remoteproc in sysfs directory $1; names are
# usually unique and are kept as-is so that results stay comparable across
# runs, but a SoC may have several remoteprocs sharing a name, in which case a
# stable device identifier is added to tell them apart
test_case_name() {
    local dir="$1"
    local name
    name="$(cat "${dir}/name")"
    if [ "$(remoteprocs_by_name "${name}" | wc -l)" -gt 1 ]; then
        echo "remoteproc-${name}-$(remoteproc_id "${dir}")-running"
    else
        echo "remoteproc-${name}-running"
    fi
}

# test that the remoteproc in sysfs directory $1 is running
test_remoteproc_state() {
    local dir="$1"
    local name
    local state
    local test_case

    name="$(cat "${dir}/name")"
    state="$(cat "${dir}/state" 2>/dev/null)"
    test_case="$(test_case_name "${dir}")"
    info_msg "$(basename "${dir}") ${name} state is ${state:-unreadable}"

    # report the state above even for remoteprocs which are not tested, it is
    # useful when triaging a job
    if is_skipped "${name}"; then
        info_msg "${name} is not expected to be running, skipping"
        report_skip "${test_case}"
        return
    fi

    # "running" is a remoteproc which Linux booted, "attached" one which was
    # already running when Linux took over
    case "${state}" in
      running|attached) report_pass "${test_case}" ;;
      *) report_fail "${test_case}" ;;
    esac

    # rproc_report_crash() logs "remoteproc<N>: crash detected in <name>: ..."
    crash_case="${test_case%-running}-no-crash"
    if ! dmesg > "${OUTPUT}/dmesg.txt" 2>/dev/null; then
        report_skip "${crash_case}"
    elif grep -F "$(basename "${dir}"): crash detected in ${name}:" "${OUTPUT}/dmesg.txt"; then
        report_fail "${crash_case}"
    else
        report_pass "${crash_case}"
    fi
}

# print the reason remoteproc $1 is listed with in EXPECTED_FAIL, if any
expected_fail_reason() {
    echo "${EXPECTED_FAIL}" | tr ';' '\n' |
        awk -F= -v n="$1" '{ k = $1; gsub(/ /, "", k) } k == n { sub(/^[^=]*= */, ""); print; exit }'
}

# result <case> <pass|fail> [<measurement> <unit>]
result() {
    if [ "$#" -ge 4 ]; then
        add_metric "$1" "$2" "$3" "$4"
    elif [ "$2" = pass ]; then
        report_pass "$1"
    else
        report_fail "$1"
    fi
}

state() {
    cat "${DIR}/state" 2>/dev/null
}

# write_state <stop|start>: exit status of the sysfs write, 124 when it has
# not returned after RESTART_TIMEOUT (a remoteproc stuck in its stop or start
# path must not hang the test).
write_state() {
    local pid
    local i=0
    (echo "$1" > "${DIR}/state") 2> "${OUTPUT}/write.err" &
    pid=$!
    while kill -0 "${pid}" 2>/dev/null; do
        if [ "${i}" -ge "${RESTART_TIMEOUT}" ]; then
            kill "${pid}" 2>/dev/null
            return 124
        fi
        sleep 1
        i=$((i + 1))
    done
    wait "${pid}"
}

# wait_state <state>: seconds until the remoteproc reads <state>, or fail
wait_state() {
    local i=0
    while [ "$(state)" != "$1" ]; do
        [ "${i}" -ge "${RESTART_TIMEOUT}" ] && return 1
        sleep 1
        i=$((i + 1))
    done
    echo "${i}"
}

# channels: "<rpmsg device> <driver or ->" for every rpmsg device below the
# remoteproc's device (its glink or smd edge)
channels() {
    local dev
    local drv
    dev="$(readlink -f "${DIR}/device")"
    for r in "${SYSFS_RPMSG}"/*; do
        [ -e "${r}" ] || continue
        case "$(readlink -f "${r}")" in
            "${dev}"/*) ;;
            *) continue ;;
        esac
        drv="-"
        [ -e "${r}/driver" ] && drv="$(basename "$(readlink -f "${r}/driver")")"
        echo "$(basename "${r}") ${drv}"
    done | sort
}

# missing_channels <list>: lines of <list> not in the current channels
missing_channels() {
    local now
    now="$(channels)"
    echo "$1" | while read -r line; do
        [ -n "${line}" ] || continue
        echo "${now}" | grep -qxF "${line}" || echo "${line}"
    done
}

# mark: put a unique line in the kernel log to find this step's messages
mark() {
    MARK="remoteproc-smoke: ${CASE} iteration $1 at $(cut -d' ' -f1 /proc/uptime)"
    T0="$(cut -d' ' -f1 /proc/uptime)"
    echo "<6>${MARK}" 2>/dev/null > /dev/kmsg || MARK=""
}

# since_mark: kernel log lines after the last mark (or, without /dev/kmsg,
# after its uptime)
since_mark() {
    if [ -n "${MARK}" ] && dmesg | grep -qF "${MARK}"; then
        dmesg | awk -v m="${MARK}" 'f { print } index($0, m) { f = 1 }'
    else
        dmesg | awk -v t="${T0}" '{ s = $0; sub(/^\[ */, "", s); if (s + 0 > t) print }'
    fi
}

skip_from() { # <iteration> <first step to skip>
    local i="$1"
    local skipping=""
    while [ "${i}" -le "${ITERATIONS}" ]; do
        for s in ${STEPS}; do
            [ "${s}" = "$2" ] && skipping=1
            [ -n "${skipping}" ] && report_skip "${CASE}-${s}-${i}"
        done
        skipping=1
        i=$((i + 1))
    done
}

# restart_iteration <i>: one stop and start; returns 1 after a failed step
# once the following steps cannot run, 0 otherwise. The rpmsg devices must
# come back as they were before the first stop (BEFORE).
restart_iteration() {
    local i="$1"
    local rc
    local t
    local s0
    local lost
    local log
    local n

    mark "${i}"
    s0="$(state)"
    if [ "${s0}" = running ] || [ "${s0}" = attached ]; then
        write_state stop
        rc=$?
        if [ "${rc}" -eq 0 ]; then
            result "${CASE}-stop-${i}" pass
        else
            info_msg "${CASE}: stop returned ${rc}: $(cat "${OUTPUT}/write.err" 2>/dev/null)"
            result "${CASE}-stop-${i}" fail
        fi
    else
        info_msg "${CASE}: ${s0:-no state} before the stop, not running"
        result "${CASE}-stop-${i}" fail
    fi
    if t="$(wait_state offline)"; then
        result "${CASE}-offline-${i}" pass "${t}" s
    else
        info_msg "${CASE}: $(state) ${RESTART_TIMEOUT} s after the stop"
        result "${CASE}-offline-${i}" fail
        since_mark | head -n 40
        skip_from "${i}" start
        return 1
    fi
    if [ -n "$(channels)" ]; then
        info_msg "${CASE}: rpmsg devices left after the stop:"
        channels
    fi

    t="$(date +%s)"
    write_state start
    rc=$?
    t=$(($(date +%s) - t))
    if [ "${rc}" -eq 0 ]; then
        result "${CASE}-start-${i}" pass "${t}" s
    else
        info_msg "${CASE}: start returned ${rc}: $(cat "${OUTPUT}/write.err" 2>/dev/null)"
        result "${CASE}-start-${i}" fail
    fi
    if t="$(wait_state running)"; then
        result "${CASE}-running-${i}" pass "${t}" s
    else
        info_msg "${CASE}: $(state) ${RESTART_TIMEOUT} s after the start"
        result "${CASE}-running-${i}" fail
        since_mark | head -n 40
        skip_from "${i}" channels
        return 1
    fi

    n="$(echo "${BEFORE}" | grep -c .)"
    if [ "${n}" -eq 0 ]; then
        info_msg "${CASE}: no rpmsg devices before the first stop"
        report_skip "${CASE}-channels-${i}"
    else
        t=0
        lost="$(missing_channels "${BEFORE}")"
        while [ -n "${lost}" ] && [ "${t}" -lt "${RESTART_TIMEOUT}" ]; do
            sleep 1
            t=$((t + 1))
            lost="$(missing_channels "${BEFORE}")"
        done
        if [ -z "${lost}" ]; then
            result "${CASE}-channels-${i}" pass "${n}" channels
        else
            info_msg "${CASE}: not back (rpmsg device, driver) after ${t} s:"
            echo "${lost}"
            info_msg "${CASE}: now:"
            channels
            result "${CASE}-channels-${i}" fail
        fi
    fi

    sleep "${SETTLE_TIME}"
    log="$(since_mark)"
    n="$(echo "${log}" | grep -cE "${ISSUES}")"
    if [ "${n}" -eq 0 ] && [ "$(state)" = running ]; then
        result "${CASE}-kernel-clean-${i}" pass 0 lines
    else
        info_msg "${CASE}: $(state) ${SETTLE_TIME} s after the start, ${n} lines:"
        echo "${log}" | grep -E "${ISSUES}" | head -n 20
        result "${CASE}-kernel-clean-${i}" fail "${n}" lines
    fi
    return 0
}

# restart the remoteproc in sysfs directory $1 ITERATIONS times
restart_remoteproc() {
    local i=1
    local name
    local reason
    local s_start
    DIR="$1"
    name="$(cat "${DIR}/name")"
    CASE="$(test_case_name "${DIR}")"
    CASE="${CASE%-running}"
    if is_skipped "${name}"; then
        return
    fi
    reason="$(expected_fail_reason "${name}")"
    if [ -n "${reason}" ]; then
        info_msg "${name} is expected to fail a restart (${reason}), not restarted"
        report_skip "${CASE}-restart"
        return
    fi
    s_start="$(state)"
    BEFORE="$(channels)"
    info_msg "${CASE}: $(basename "${DIR}"), ${s_start}, ${ITERATIONS} restarts"
    if [ -n "${BEFORE}" ]; then
        info_msg "${CASE}: rpmsg devices (device, driver):"
        echo "${BEFORE}"
    fi
    while [ "${i}" -le "${ITERATIONS}" ]; do
        if ! restart_iteration "${i}"; then
            break
        fi
        i=$((i + 1))
    done
    # Leave a remoteproc that was running before the restarts running, for
    # the tests after this one.
    if { [ "${s_start}" = running ] || [ "${s_start}" = attached ]; } && [ "$(state)" = offline ]; then
        write_state start
        wait_state running > /dev/null
    fi
    info_msg "${CASE}: $(state) at the end"
}

# helper function to wait for remoteproc(s) to be enumerated. When DEVICE is
# unset, wait for any remoteproc to be enumerated.
wait_for_device() {
    info_msg "Waiting ${WAIT_TIME} seconds for requested device to exist..."
    for i in $(seq 1 "${WAIT_TIME}")
    do
      if [ -n "${DEVICE}" ]; then
          # wait for all of the requested remoteprocs, not just the first one
          missing=""
          for name in ${DEVICE}; do
              [ -z "$(remoteprocs_by_name "${name}")" ] && missing="${name}"
          done
          [ -z "${missing}" ] && break
      else
          [ -n "$(list_remoteprocs)" ] && break
      fi
      sleep 1
    done
}

# Test run.
create_out_dir "${OUTPUT}"

info_msg "About to run remoteproc smoke test..."
info_msg "Output directory: ${OUTPUT}"

# remoteprocs are booted asynchronously, so they may not be enumerated yet
wait_for_device

# a DUT without any remoteproc has nothing to test; report this as a skip
# rather than a failure regardless of whether specific remoteprocs were
# requested
all_dirs="$(list_remoteprocs)"
if [ -z "${all_dirs}" ]; then
    report_skip "remoteproc-device-exists"
    exit 0
fi
report_pass "remoteproc-device-exists"

if [ -n "${DEVICE}" ]; then
    # a requested remoteproc which doesn't exist is a failure, unless it is one
    # which is not expected to be running anyway
    dirs=""
    for name in ${DEVICE}; do
        found="$(remoteprocs_by_name "${name}")"
        if [ -z "${found}" ]; then
            info_msg "No remoteproc named ${name}"
            if is_skipped "${name}"; then
                report_skip "remoteproc-${name}-running"
            else
                report_fail "remoteproc-${name}-running"
            fi
            continue
        fi
        dirs="${dirs} ${found}"
    done
    # the same remoteproc may be requested more than once, or a name may match
    # several sysfs directories; drop duplicates so each is tested only once
    dirs="$(printf '%s\n' ${dirs} | sort -u)"
else
    # auto-detect all of the remoteprocs present on the DUT
    dirs="${all_dirs}"
fi

# test case names embed the remoteproc name, so they are unique and stay
# comparable across runs
for dir in ${dirs}; do
    test_remoteproc_state "${dir}"
done

if [ "${ITERATIONS}" -gt 0 ]; then
    for dir in ${dirs}; do
        restart_remoteproc "${dir}"
    done
fi

exit 0
