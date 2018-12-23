#!/bin/sh -e

OUTPUT="$(pwd)/output"
BOOT_TIMEOUT="300"
LOGFILE="${OUTPUT}/gtest-gatekeeper-keymaster-stdout.log"
RESULT_FILE="${OUTPUT}/result.txt"

usage() {
    echo "Usage: $0 [-s <android_serial>] [-t <boot_timeout>]" 1>&2
    exit 1
}

while getopts ":s:t:" o; do
  case "$o" in
    s) ANDROID_SERIAL="${OPTARG}" ;;
    t) BOOT_TIMEOUT="${OPTARG}" ;;
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
info_msg "About to run gatekeeper and keymaster gtests on device ${ANDROID_SERIAL}"

adb shell "echo /data/nativetest/VtsHalGatekeeperV1_0TargetTest/VtsHalGatekeeperV1_0TargetTest 2>&1 | su" | tee -a "${LOGFILE}"
adb shell "echo /data/nativetest/VtsHalKeymasterV3_0TargetTest/VtsHalKeymasterV3_0TargetTest 2>&1 | su" | tee -a "${LOGFILE}"
adb shell "echo /data/nativetest64/VtsHalGatekeeperV1_0TargetTest/VtsHalGatekeeperV1_0TargetTest 2>&1 | su" | tee -a "${LOGFILE}"
adb shell "echo /data/nativetest64/VtsHalKeymasterV3_0TargetTest/VtsHalKeymasterV3_0TargetTest 2>&1 | su" | tee -a "${LOGFILE}"

# Parse test log into RESULT_FILE
grep "\[ *OK *\] [A-Za-z]" "${LOGFILE}" | awk '{printf("%s pass\n", $4)}' | tee -a "${RESULT_FILE}"
grep "\[ *FAILED *\] [A-Za-z]" "${LOGFILE}" | awk '{printf("%s fail\n", $4)}' | tee -a "${RESULT_FILE}"
