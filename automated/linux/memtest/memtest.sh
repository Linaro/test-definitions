#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2026 Qualcomm Technologies, Inc. and/or its subsidiaries.
#
# Check the kernel's early memory test. With CONFIG_MEMTEST and memtest=N on
# the command line, the kernel writes and verifies N patterns over all free
# memory before the other CPUs start, logs "early_memtest: # of tests: N",
# one line per memory range and pattern, and a "bad mem addr" line for each
# range that failed, which it reserves (/proc/meminfo EarlyMemtestBad).
#
# memtest-patterns passes when the expected number of patterns ran;
# memtest-bad-memory passes when no bad memory was reported. Both are
# skipped when memtest= is not set or the kernel lacks CONFIG_MEMTEST.

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE

PATTERNS=""
# Size of the kernel's pattern table: a bare "memtest" runs all of them.
ALL_PATTERNS=17
RANGE_RE='0x[0-9a-f]+ - 0x[0-9a-f]+ pattern [0-9a-f]{16}'

usage() {
    echo "Usage: $0 [-n <number of patterns>]" 1>&2
    exit 1
}

while getopts "n:h" o; do
    case "$o" in
        n) PATTERNS="${OPTARG}" ;;
        h|*) usage ;;
    esac
done

skip_all() {
    info_msg "$1"
    report_skip "memtest-patterns"
    report_skip "memtest-bad-memory"
    exit 0
}

create_out_dir "${OUTPUT}"
LOG="${OUTPUT}/dmesg.txt"
dmesg > "${LOG}" || skip_all "cannot read the kernel log"

arg="$(tr ' ' '\n' < /proc/cmdline |
    sed -n -e 's/^memtest=//p' -e "s/^memtest\$/${ALL_PATTERNS}/p" | tail -n 1)"
info_msg "kernel command line memtest: ${arg:-none}"
[ -n "${arg}" ] || skip_all "memtest= is not set"
arg="$(printf '%d' "${arg}" 2> /dev/null)" || arg=""
if [ -z "${arg}" ] || [ "${arg}" -le 0 ]; then
    skip_all "memtest= disables the memory test"
fi

find_config_file
# shellcheck disable=SC2154
if [ -f "${kernel_config}" ] && ! grep -qx "CONFIG_MEMTEST=y" "${kernel_config}"; then
    skip_all "the kernel lacks CONFIG_MEMTEST"
fi
# Without CONFIG_MEMTEST the kernel does not know the parameter.
if grep "Unknown kernel command line parameters" "${LOG}" |
        grep -qE "[\" ]memtest(=[^ \"]*)?[\" ]"; then
    skip_all "the kernel lacks CONFIG_MEMTEST (memtest= is an unknown parameter)"
fi

expected="${PATTERNS:-${arg}}"
grep -E "early_memtest:|${RANGE_RE}|bad mem addr" "${LOG}" > "${OUTPUT}/memtest.txt"
cat "${OUTPUT}/memtest.txt"

tests="$(sed -n 's/.*early_memtest: # of tests: \([0-9]*\).*/\1/p' "${LOG}" | tail -n 1)"
# Consecutive passes use different patterns, so each change starts a pass.
passes="$(grep -oE "${RANGE_RE}" "${LOG}" | sed 's/.* pattern //' | uniq | wc -l)"
if [ -z "${tests}" ]; then
    warn_msg "no early_memtest line in the kernel log (log buffer overwritten?)"
    report_fail "memtest-patterns"
else
    # Bytes covered by the first pass, one line per free memory range.
    first="$(grep -oE "${RANGE_RE}" "${LOG}" | head -n 1 | sed 's/.* pattern //')"
    grep -oE "${RANGE_RE}" "${LOG}" | grep " pattern ${first}\$" > "${OUTPUT}/first-pass.txt"
    bytes=0
    while read -r start _ end _; do
        bytes=$((bytes + end - start))
    done < "${OUTPUT}/first-pass.txt"
    info_msg "kernel ran ${tests} of ${expected} expected patterns in ${passes} passes; first pass covered $((bytes / 1048576)) MiB"
    if [ "${tests}" -eq "${expected}" ] && [ "${passes}" -eq "${expected}" ]; then
        add_metric "memtest-patterns" "pass" "${passes}" "patterns"
    else
        add_metric "memtest-patterns" "fail" "${passes}" "patterns"
    fi
fi

bad_lines="$(grep -c "bad mem addr" "${LOG}")"
bad_kb="$(awk '/^EarlyMemtestBad:/ { print $2 }' /proc/meminfo)"
info_msg "bad mem addr lines: ${bad_lines}, EarlyMemtestBad: ${bad_kb:-not reported} kB"
if [ "${bad_lines}" -eq 0 ] && [ "${bad_kb:-0}" -eq 0 ]; then
    add_metric "memtest-bad-memory" "pass" "${bad_kb:-0}" "kB"
else
    add_metric "memtest-bad-memory" "fail" "${bad_kb:-0}" "kB"
fi
exit 0
