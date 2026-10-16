#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2026 Qualcomm Technologies, Inc. and/or its subsidiaries.
#
# FastRPC round trips to the DSPs with fastrpc_test from
# https://github.com/qualcomm/fastrpc. Each test names a remoteproc, a
# FastRPC domain and a protection domain; the remoteproc must be running and
# fastrpc_test must pass. DSPs fastrpc_test cannot call (e.g. GPDSP) are
# checked for their device node only. Without fastrpc_test or the named
# remoteproc the case is skipped.

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE

# <case>:<remoteproc>:<domain>:<unsigned PD 0|1>
TESTS="adsp:adsp:0:0 cdsp:cdsp:3:0 cdsp-unsigned-pd:cdsp:3:1"
# <remoteproc>:<device node prefix>
NODES=""

usage() {
    echo "Usage: $0 [-t '<case>:<rproc>:<domain>:<unsigned> ...'] [-n '<rproc>:<node> ...']" 1>&2
    exit 1
}

while getopts "t:n:h" o; do
    case "$o" in
        t) TESTS="${OPTARG}" ;;
        n) NODES="${OPTARG}" ;;
        h|*) usage ;;
    esac
done

# rproc_state <name>: state of the first remoteproc called <name>
rproc_state() {
    r="$(remoteproc_dirs "$1" | head -n 1)"
    [ -z "${r}" ] || cat "${r}/state"
}

create_out_dir "${OUTPUT}"

for t in ${TESTS}; do
    name="fastrpc-${t%%:*}"
    rest="${t#*:}"
    rproc="${rest%%:*}"
    rest="${rest#*:}"
    domain="${rest%%:*}"
    unsigned="${rest#*:}"
    state="$(rproc_state "${rproc}")"
    info_msg "${name}: remoteproc ${rproc} ${state:-not registered}"
    if [ -z "${state}" ]; then
        report_skip "${name}"
        continue
    fi
    if ! command -v fastrpc_test > /dev/null; then
        warn_msg "fastrpc_test is not installed"
        report_skip "${name}"
        continue
    fi
    if [ "${state}" != running ] && [ "${state}" != attached ]; then
        report_fail "${name}"
        continue
    fi
    fastrpc_test -d "${domain}" -U "${unsigned}" > "${OUTPUT}/${name}.log" 2>&1
    rc=$?
    cat "${OUTPUT}/${name}.log"
    if [ "${rc}" -eq 0 ]; then
        report_pass "${name}"
    else
        info_msg "fastrpc_test -d ${domain} -U ${unsigned} exited ${rc}"
        report_fail "${name}"
    fi
done

for n in ${NODES}; do
    rproc="${n%%:*}"
    node="${n#*:}"
    name="fastrpc-${rproc}-node"
    state="$(rproc_state "${rproc}")"
    info_msg "${name}: remoteproc ${rproc} ${state:-not registered}"
    if [ -z "${state}" ]; then
        report_skip "${name}"
        continue
    fi
    ls -l "${node}"* 2>&1
    if { [ "${state}" = running ] || [ "${state}" = attached ]; } &&
       ls "${node}"* > /dev/null 2>&1; then
        report_pass "${name}"
    else
        report_fail "${name}"
    fi
done
exit 0
