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


initialize_adb
adb_root
create_out_dir "${OUTPUT}"
# wait till the launcher displayed
if wait_boot_completed "${BOOT_TIMEOUT}"; then
	report_pass android-boot
else
	report_fail android-boot
fi
