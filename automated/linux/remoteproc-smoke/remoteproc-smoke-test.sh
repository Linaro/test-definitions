#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2026 Qualcomm Technologies, Inc. and/or its subsidiaries.
#
# remoteproc smoke tests
#
# Check that the remoteprocs which the kernel is expected to boot are running,
# to catch regressions where a DSP silently fails to come up, e.g. because its
# firmware could not be loaded.

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

usage() {
    echo "Usage: $0 [-d <remoteprocs>] [-s <remoteprocs>] [-w <wait_time>]" 1>&2
    exit 1
}

while getopts "d:s:w:" o; do
  case "$o" in
    d) DEVICE="${OPTARG}" ;;
    s) SKIP="${OPTARG}" ;;
    w) WAIT_TIME="${OPTARG}" ;;
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

exit 0
