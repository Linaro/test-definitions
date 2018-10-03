#!/bin/sh -e
# shellcheck disable=SC1091

ANDROID_SERIAL=""
BOOT_TIMEOUT="300"
OUTPUT="$(pwd)/output"
export RESULT_FILE="${OUTPUT}/result.txt"

. ../../lib/sh-test-lib
. ../../lib/android-test-lib

usage() {
    echo "Usage: $0 [-s <android_serial>] [-t <boot_timeout>] " 1>&2
    exit 1
}

while getopts ":S:s:t:o:n:" o; do
  case "$o" in
    s) export ANDROID_SERIAL="${OPTARG}" ;;
    t) BOOT_TIMEOUT="${OPTARG}" ;;
    *) usage ;;
  esac
done


safe_initialize_adb() {
    # enable debug
    set -x
    adb_debug_info
    adb start-server
    timeout 300 adb wait-for-device || error_msg "Device NOT found!"
    adb devices

    if [ -z "${ANDROID_SERIAL}" ]; then
        number="$(adb devices | grep -wc 'device')"
        if [ "${number}" -gt 1 ]; then
            error_msg "More than one device or emulator found! Please set ANDROID_SERIAL from test script."
        elif [ "${number}" -eq 1 ]; then
            ANDROID_SERIAL="$(adb get-serialno)"
        else
            error_msg "Device NOT found"
        fi
    fi
    export ANDROID_SERIAL
    info_msg "Default adb device: ${ANDROID_SERIAL}"

    if adb shell echo "Testing adb connectivity"; then
        info_msg "Connected to device ${ANDROID_SERIAL} successfully"
    else
        error_msg "Unable to connect to device ${ANDROID_SERIAL}"
    fi
    # disable debug
    set +x
}

safe_initialize_adb
adb_root
create_out_dir "${OUTPUT}"
# wait till the launcher displayed
if wait_boot_completed "${BOOT_TIMEOUT}"; then
	report_pass android-boot
else
	report_fail android-boot
fi
