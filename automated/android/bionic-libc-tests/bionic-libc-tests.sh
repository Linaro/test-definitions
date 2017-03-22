#!/bin/sh

HOST_OUTPUT="$(pwd)/output"
DEVICE_OUTPUT="/data/local/tmp/result.txt"
export RESULT_FILE
TIMEOUT=300

usage() {
    echo "Usage: $0" 1>&2
    exit 1
}

if [ $# -gt 0 ]; then
    usage
fi

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
. ../../lib/android-test-lib

# Test run.
create_out_dir "${HOST_OUTPUT}"

initialize_adb
wait_boot_completed "${TIMEOUT}"
adb_push "./device-script.sh" "/data/local/tmp/"

info_msg "About to run bionic-libc-tests on device ${ANDROID_SERIAL}"
adb shell /data/local/tmp/device-script.sh 2>&1 \
    | tee "${HOST_OUTPUT}"/device-run.log

adb_pull "${DEVICE_OUTPUT}" "${HOST_OUTPUT}"
