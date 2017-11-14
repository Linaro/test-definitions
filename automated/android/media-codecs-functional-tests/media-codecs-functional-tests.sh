#!/bin/sh -e

OUTPUT="$(pwd)/output"
LOGFILE="${OUTPUT}/media-codecs-functional-tests.log"
RESULT_FILE="${OUTPUT}/result.txt"
ANDROID_SERIAL=""
BOOT_TIMEOUT="300"

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
# shellcheck disable=SC1091
. ../../lib/android-test-lib

parse_common_args "$@"
initialize_adb
wait_boot_completed "${BOOT_TIMEOUT}"
create_out_dir "${OUTPUT}"

# make sure the script /system/bin/linaro-android-userspace-tests.sh exists
if ! adb_shell_which "/system/bin/linaro-android-userspace-tests.sh"; then
    report_fail "check_cmd_existence"
    exit 1
fi

# Run test script.
info_msg "device-${ANDROID_SERIAL}: About to run media codecs functional tests..."
adb shell "echo /system/bin/linaro-android-userspace-tests.sh | su" \
    | tee "${LOGFILE}"

# Parse test log.
grep -E "[[].+[]]: test (passed|failed|skipped)" "${LOGFILE}" \
    | sed 's/[]:[]//g' \
    | sed 's/passed/pass/; s/failed/fail/; s/skipped/skip/' \
    | awk '{printf("%s %s\n", $1, $NF)}' \
    | tee -a "${RESULT_FILE}"
