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
    timeout 300 adb wait-for-device || info_msg "Device NOT found!"
    adb devices

    if [ -z "${ANDROID_SERIAL}" ]; then
        number="$(adb devices | grep -wc 'device')"
        if [ "${number}" -gt 1 ]; then
            info_msg "More than one device or emulator found! Please set ANDROID_SERIAL from test script."
        elif [ "${number}" -eq 1 ]; then
            ANDROID_SERIAL="$(adb get-serialno)"
        else
            info_msg "Device NOT found"
        fi
    fi
    export ANDROID_SERIAL
    info_msg "Default adb device: ${ANDROID_SERIAL}"

    if adb shell echo "Testing adb connectivity"; then
        info_msg "Connected to device ${ANDROID_SERIAL} successfully"
    else
        info_msg "Unable to connect to device ${ANDROID_SERIAL}"
    fi
    # disable debug
    set +x
}

safe_wait_boot_completed() {
    [ "$#" -ne 1 ] && info_msg "Usage: wait_for_boot_completed timeout_in_seconds"
    timeout="$1"
    end=$(( $(date +%s) + timeout ))

    boot_completed=false
    while [ "$(date +%s)" -lt "$end" ]; do
        if adb shell getprop sys.boot_completed | grep "1"; then
            boot_completed=true
            break
        else
            sleep 3
        fi
    done

    if "${boot_completed}"; then
        info_msg "Target booted up completely."
    else
        info_msg "wait_boot_completed timed out after ${timeout} seconds"
    fi
}

safe_initialize_adb
adb_root
create_out_dir "${OUTPUT}"
# wait till the launcher displayed
if safe_wait_boot_completed "${BOOT_TIMEOUT}"; then
    report_pass android-boot
else
    report_fail android-boot
fi
