#!/bin/sh -e

LEVEL="0"
TEST_SUITE="regression"
OUTPUT="$(pwd)/output"
BOOT_TIMEOUT="300"
LOGFILE="${OUTPUT}/xtest-${TEST_SUITE}-stdout.log"
RESULT_FILE="${OUTPUT}/result.txt"

usage() {
    echo "Usage: $0 [-s <android_serial>] [-t <boot_timeout>] [-l <level>] [-T <test_suite>]" 1>&2
    exit 1
}

while getopts ":s:t:l:T:" o; do
  case "$o" in
    s) ANDROID_SERIAL="${OPTARG}" ;;
    t) BOOT_TIMEOUT="${OPTARG}" ;;
    l) LEVEL="${OPTARG}" ;;
    T) TEST_SUITE="${OPTARG}" ;;
    *) usage ;;
  esac
done

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
# shellcheck disable=SC1091
. ../../lib/android-test-lib

initialize_adb
wait_boot_completed "${BOOT_TIMEOUT}"
create_out_dir "${OUTPUT}"

# Run test.
info_msg "About to run optee-xtest on device ${ANDROID_SERIAL}"
if ! adb_shell_which "tee-supplicant"; then
    report_fail "check-tee-supplicant-existence"
    exit 0
fi
adb shell "echo 'tee-supplicant &' | su"

if ! adb_shell_which "xtest"; then
    report_fail "check-xtest-existence"
    exit 0
fi
adb shell "echo xtest -l ${LEVEL} -t ${TEST_SUITE} 2>&1 | su" | tee "${LOGFILE}"

# Parse xtest test log.
awk "/Result of testsuite ${TEST_SUITE}:/{flag=1; next} /\+-----------------------------------------------------/{flag=0} flag" "${LOGFILE}" \
    | sed 's/OK/pass/; s/FAILED/fail/; s/SKIPPED/skip/' \
    | awk '{printf("%s %s\n", $1, $2)}' \
    | tee -a "${RESULT_FILE}"

# Parse test pass/fail/skip stats.
for i in "subtests" "test cases"; do
    grep -E "^[0-9]+ $i of which [0-9]+ failed" "${LOGFILE}" \
        | awk -v tc="$(echo "$i" | sed 's/ /-/')" \
              '{printf("%s-fail-rate pass %s\n"), tc, $(NF-1)/$1}' \
        | tee -a "${RESULT_FILE}"
done

grep -E "^[0-9]+ test case was skipped" "${LOGFILE}" \
    | awk '{printf("test-skipped pass %s\n", $1)}' \
    | tee -a "${RESULT_FILE}"
