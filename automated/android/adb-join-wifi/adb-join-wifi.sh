#!/bin/sh -e
# shellcheck disable=SC1091

OUTPUT="$(pwd)/output"
LOGFILE="${OUTPUT}/ping.log"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE
ANDROID_SERIAL=""
BOOT_TIMEOUT="300"
SERVER="www.google.com"
AP_SSID=""
AP_KEY=""

usage() {
    echo "Usage: $0 [-s <android_serial>] [-t <boot_timeout>] [-S <server>] [-a <ap_ssid>] [-k <ap_key>]" 1>&2
    exit 1
}

while getopts ":s:t:S:a:k:" o; do
  case "$o" in
    s) ANDROID_SERIAL="${PTARG}" ;;
    t) BOOT_TIMEOUT="${OPTARG}" ;;
    S) SERVER="${OPTARG}" ;;
    a) AP_SSID="${OPTARG}" ;;
    k) AP_KEY="${OPTARG}" ;;
    *) usage ;;
  esac
done

. ../../lib/sh-test-lib
. ../../lib/android-test-lib

initialize_adb
wait_boot_completed "${BOOT_TIMEOUT}"
create_out_dir "${OUTPUT}"
adb_root

# try to connect wifi if AP information specified
adb_join_wifi "${AP_SSID}" "${AP_KEY}"

# wait for a while till the wifi connecting operation finished
sleep 60

info_msg "device-${ANDROID_SERIAL}: About to check with ping ${SERVER}..."
adb shell 'ping -c 10 '"${SERVER}"'; echo exitcode: $?' | tee "${LOGFILE}"
if grep -q "exitcode: 0" "${LOGFILE}"; then
    report_pass "adb_join_wifi"
else
    report_fail "adb_join_wifi"
fi
