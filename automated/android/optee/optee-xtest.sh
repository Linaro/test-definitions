#!/bin/sh -ex

LEVEL="0"
TEST_SUITE="regression"
OUTPUT="$(pwd)/output"
BOOT_TIMEOUT="300"
LOGFILE="${OUTPUT}/xtest-${TEST_SUITE}-stdout.log"
RESULT_FILE="${OUTPUT}/result.txt"
export  RESULT_FILE

usage() {
    echo "Usage: $0 [-l <level>] [-t <test_suite>] [-b <timeout>]" 1>&2
    exit 1
}

while getopts ":l:t:b:" o; do
  case "$o" in
    l) LEVEL="${OPTARG}" ;;
    t) TEST_SUITE="${OPTARG}" ;;
    b) BOOT_TIMEOUT="${OPTARG}" ;;
    *) usage ;;
  esac
done

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
# shellcheck disable=SC1091
. ../../lib/android-test-lib

# Test run.
create_out_dir "${OUTPUT}"

initialize_adb
adb_root
wait_boot_completed "${BOOT_TIMEOUT}"

info_msg "About to run optee-xtest on device ${SN}"

if test -n "$(adb -s "${SN}" shell "which tee-supplicant")"; then
    adb -s "${SN}" shell "tee-supplicant &"
else
    error_msg "tee-supplicant NOT found"
fi

if test -n "$(adb -s "${SN}" shell "which xtest")"; then
    adb -s "${SN}" shell "xtest -l ${LEVEL} -t ${TEST_SUITE} 2>&1" | tee "${LOGFILE}"
else
    error_msg "xtest NOT found"
fi

# Save xtest result.
grep "^XTEST_TEE" "${LOGFILE}" \
    | sed 's/OK/pass/; s/FAILED/fail/; s/SKIPPED/skip/' \
    | awk '{printf("%s %s\n", $1, $2)}' \
    | tee -a "${RESULT_FILE}"

# Save test pass/fail/skip stats.
for i in "subtests" "test cases"; do
    grep -E "^[0-9]+ $i of which [0-9]+ failed" "${LOGFILE}" \
        | awk -v tc="$(echo "$i" | sed 's/ /-/')" \
              '{printf("%s-fail-rate pass %s/%s\n"), tc, $(NF-1), $1}' \
        | tee -a "${RESULT_FILE}"
done

grep -E "^[0-9]+ test case was skipped" "${LOGFILE}" \
    | awk '{printf("test-skipped pass %s\n", $1)}' \
    | tee -a "${RESULT_FILE}"
