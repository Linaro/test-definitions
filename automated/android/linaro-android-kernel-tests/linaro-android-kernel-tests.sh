#!/bin/sh -e

OUTPUT="$(pwd)/output"
LOGFILE="${OUTPUT}/linaro-android-kernel-tests.log"
RESULT_FILE="${OUTPUT}/result.txt"
TEST_SCRIPT="linaro-android-kernel-tests.sh"

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
# shellcheck disable=SC1091
. ../../lib/android-test-lib

initialize_adb
adb_root
wait_boot_completed "300"
create_out_dir "${OUTPUT}"

# Run test script.
if test -n "$(adb shell "which ${TEST_SCRIPT}")"; then
    adb shell "${TEST_SCRIPT}" | tee "${LOGFILE}"
else
    warn_msg "${TEST_SCRIPT} NOT found"
    report_fail "test-script-existence-check"
    exit 0
fi

# Parse test log.
grep -E "test (passed|failed|skipped)" "${LOGFILE}" \
    | sed 's/[]*:[]//g; s/^0 //g' \
    | sed 's/passed/pass/; s/failed/fail/; s/skipped/skip/' \
    | awk '{printf("%s %s\n", $1, $NF)}' \
    | tee -a "${RESULT_FILE}"
