#!/bin/sh -e
# shellcheck disable=SC1091

OUTPUT="$(pwd)/output"
LOGFILE="${OUTPUT}/ping.log"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE
ANDROID_SERIAL=""
BOOT_TIMEOUT="300"
SERVER="www.google.com"

usage() {
    echo "Usage: $0 [-s <android_serial>] [-t <boot_timeout>] [-S <server>]" 1>&2
    exit 1
}

while getopts ":s:t:S:" o; do
  case "$o" in
    s) ANDROID_SERIAL="${OPTARG}" ;;
    t) BOOT_TIMEOUT="${OPTARG}" ;;
    S) SERVER="${OPTARG}" ;;
    *) usage ;;
  esac
done

. ../../lib/sh-test-lib
. ../../lib/android-test-lib

initialize_adb
wait_boot_completed "${BOOT_TIMEOUT}"
create_out_dir "${OUTPUT}"

info_msg "device-${ANDROID_SERIAL}: About to ping ${SERVER}..."
adb shell 'ping -c 10 '"${SERVER}"'; echo exitcode: $?' | tee "${LOGFILE}"

if grep -q "exitcode: 0" "${LOGFILE}"; then
    report_pass "ping"
else
    report_fail "ping"
fi
