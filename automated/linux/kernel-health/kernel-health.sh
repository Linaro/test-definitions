#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2026 Qualcomm Technologies, Inc. and/or its subsidiaries.
#
# Count kernel warnings, BUGs, oopses and call traces in the kernel log since
# boot. Each class is a test case with the count as its measurement; a
# class passes when its count is at most MAX. Lines matching IGNORE (an
# extended regex) are not counted. The counts only cover the whole boot
# while the log buffer still holds the kernel banner: kernel-log-complete
# fails once the buffer has wrapped and early messages are lost.

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE

MAX="0"
IGNORE=""

usage() {
    echo "Usage: $0 [-m <max per class>] [-i <ignore regex>]" 1>&2
    exit 1
}

while getopts "m:i:h" o; do
    case "$o" in
        m) MAX="${OPTARG}" ;;
        i) IGNORE="${OPTARG}" ;;
        h|*) usage ;;
    esac
done

create_out_dir "${OUTPUT}"
LOG="${OUTPUT}/dmesg.txt"
# An unreadable log (dmesg_restrict) must not pass as a clean one.
if ! dmesg > "${OUTPUT}/dmesg-all.txt"; then
    warn_msg "cannot read the kernel log"
    for name in kernel-log-complete kernel-warning kernel-bug kernel-oops kernel-call-trace kernel-panic; do
        report_skip "${name}"
    done
    exit 0
fi
if grep -q "Linux version " "${OUTPUT}/dmesg-all.txt"; then
    report_pass "kernel-log-complete"
else
    warn_msg "the kernel log no longer starts at boot: $(head -n 1 "${OUTPUT}/dmesg-all.txt")"
    report_fail "kernel-log-complete"
fi
if [ -n "${IGNORE}" ]; then
    grep -vE "${IGNORE}" "${OUTPUT}/dmesg-all.txt" > "${LOG}"
else
    cp "${OUTPUT}/dmesg-all.txt" "${LOG}"
fi

total=0
for class in "kernel-warning:WARNING:" "kernel-bug:BUG:" \
             "kernel-oops:Oops|Internal error|Unable to handle kernel" \
             "kernel-call-trace:Call trace:" "kernel-panic:Kernel panic"; do
    name="${class%%:*}"
    re="${class#*:}"
    n="$(grep -cE "${re}" "${LOG}")"
    total=$((total + n))
    grep -E "${re}" "${LOG}" | head -n 5
    if [ "${n}" -le "${MAX}" ]; then
        add_metric "${name}" "pass" "${n}" "lines"
    else
        add_metric "${name}" "fail" "${n}" "lines"
    fi
done
info_msg "${total} matching kernel log lines"
exit 0
