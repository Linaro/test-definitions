#!/bin/sh

. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
TEST_LEVEL="0"
TEST_SUITE="regression"

usage() {
    echo "Usage: $0 [-l <0-15> -t <regression|benchmark>]" 1>&2
    exit 1
}

while getopts "l:t:h:" o; do
  case "$o" in
    l) TEST_LEVEL="${OPTARG}" ;;
    t) TEST_SUITE="${OPTARG}" ;;
    h|*) usage ;;
  esac
done

parser() {
    egrep "^XTEST_TEE_.* (OK|FAILED|SKIPPED)" "${LOG_FILE}" \
        > "${OUTPUT}/raw-result.txt"

    while read line; do
        test_case=$(echo "${line}" | awk '{print $1}')
        test_result=$(echo "${line}" | awk '{print $2}')

        case "${test_result}" in
          OK) test_result="pass" ;;
          SKIPPED) test_result="skip" ;;
          *) test_result="fail" ;;
        esac

        echo "${test_case} ${test_result}" >> "${RESULT_FILE}"

        if [ "${TEST_SUITE}" = "benchmark" ]; then
            sed -n "/^\* ${test_case}/,/ ${test_case} [OK|FAILED|SKIPPED]/p" "${LOG_FILE}" \
                | grep "[0-9].*|" \
                | awk -v test_case="${test_case}" -v test_result="${test_result}"\
                '{data_size=$1; speed=$NF; print test_case"_"data_size" "test_result" "speed" KB/s"; }' \
                >> "${RESULT_FILE}"
        fi
    done < "${OUTPUT}/raw-result.txt"
}

# Test run.
[ -d "${OUTPUT}" ] && mv "${OUTPUT}" "${OUTPUT}_$(date +%Y%m%d%H%M%S)"
mkdir -p "${OUTPUT}"

command -v tee-supplicant && command -v xtest
exit_on_fail "xtest-existence-check"

tee-supplicant &
tee_supplicant_pid="$!"
sleep 5

info_msg "Running xtest..."
LOG_FILE="${OUTPUT}/${TEST_SUITE}-output.txt"
test_cmd="xtest -l ${TEST_LEVEL} -t ${TEST_SUITE} 2>&1"
pipe0_status "${test_cmd}" "tee ${LOG_FILE}"
check_return "xtest-run"

# Parse output.
parser

# Cleanup.
kill "${tee_supplicant_pid}"
