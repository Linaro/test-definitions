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

# Test run.
create_out_dir "${OUTPUT}"

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

# Parse xtest test log.
awk "/Result of testsuite ${TEST_SUITE}:/{flag=1; next} /\+-----------------------------------------------------/{flag=0} flag" "${LOG_FILE}" \
    | sed 's/OK/pass/; s/FAILED/fail/; s/SKIPPED/skip/' \
    | awk '{printf("%s %s\n", $1, $2)}' \
    | tee -a "${RESULT_FILE}"

# Parse test pass/fail/skip stats.
for i in "subtests" "test cases"; do
    grep -E "^[0-9]+ $i of which [0-9]+ failed" "${LOG_FILE}" \
        | awk -v tc="$(echo "$i" | sed 's/ /-/')" \
              '{printf("%s-fail-rate pass %s\n"), tc, $(NF-1)/$1}' \
        | tee -a "${RESULT_FILE}"
done

grep -E "^[0-9]+ test case was skipped" "${LOG_FILE}" \
    | awk '{printf("test-skipped pass %s\n", $1)}' \
    | tee -a "${RESULT_FILE}"

# Cleanup.
kill "${tee_supplicant_pid}" || true
