#!/bin/sh -e
# shellcheck disable=SC1091

OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
PROC_FILE="/proc/meminfo"

. ../../lib/sh-test-lib

create_out_dir "${OUTPUT}"

info_msg "About to check ${PROC_FILE}..."

# shellcheck disable=SC2002
cat /proc/meminfo 2>&1 | tee "${OUTPUT}/proc-meminfo"

## Parse proc-meminfo
info_msg "Parsing results from ${PROC_FILE}"
logfile="${OUTPUT}/proc-meminfo"
# Capacity info.
grep -E ".+: +[0-9]+ kB" "${logfile}" \
    | sed 's/://g' \
    | awk '{printf("%s pass %s kb\n", $1, $2)}' \
    | tee -a "${RESULT_FILE}"

# HugePages info.
grep "HugePages_" "${logfile}" \
    | sed 's/://g' \
    | awk '{printf("%s pass %s\n", $1, $2)}' \
    | tee -a "${RESULT_FILE}"
