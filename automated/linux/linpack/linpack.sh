#!/bin/sh -e

. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
ARRAY_SIZE="200"
RESULT_FILE="${OUTPUT}/result.txt"
TEST_LOG="${OUTPUT}/linpack-output.txt"

usage() {
    echo "Usage: $0 [-a <array size>]" 1>&2
    exit 1
}

while getopts "a:" o; do
    case "$o" in
        a) ARRAY_SIZE="${OPTARG}" ;;
        *) usage ;;
    esac
done

create_out_dir "${OUTPUT}"

# Run Test.
info_msg "Running linpack with array size ${ARRAY_SIZE}..."
detect_abi
# shellcheck disable=SC2154
( echo "${ARRAY_SIZE}"; echo "q" ) \
  | ./bin/"${abi}"/linpack 2>&1 \
  | tee "${TEST_LOG}"

# Parse output.
echo
egrep "^ +[0-9]+ " "${TEST_LOG}" \
      | awk -v array_size="${ARRAY_SIZE}" \
        'END{printf("linpack-%s pass %s flops\n", array_size, $NF)}' \
      | tee -a "${RESULT_FILE}"
