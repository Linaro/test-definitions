#!/bin/sh
# shellcheck disable=SC1090

TEST_DIR=$(dirname "$(realpath "$0")")
HOST_OUTPUT="${TEST_DIR}/output"
LOGFILE="${HOST_OUTPUT}/monkey-test-output.txt"
BLACKLIST_FILE="${HOST_OUTPUT}/blacklist.txt"
RESULT_FILE="${HOST_OUTPUT}/result.txt"
export RESULT_FILE

usage() {
    echo "Usage: $0 [-s <android_serial>] [-t <boot_timeout>] [-p <monkey_params>] [-b <blacklist>] [-e <event_count>] [-t <throttle>]" 1>&2
    echo "You can input no parameter and use the default value:" 1>&2
    echo "black_list: setting" 1>&2
    echo "monkey_params: --ignore-timeouts --ignore-security-exceptions --kill-process-after-error -v -v -v" 1>&2
    echo "event_count: 500" 1>&2
    echo "throttle: 200" 1>&2
    exit 1
}

# Some default parameters
ANDROID_SERIAL=""
BOOT_TIMEOUT="300"
BLACKLIST="com.android.development_settings com.android.music com.android.deskclock"
MONKEY_PARAMS="-s 1 --pct-touch 10 --pct-motion 20 --pct-nav 20 --pct-majornav 30 --pct-appswitch 20"
EVENT_COUNT="1000"
THROTTLE="200"

while getopts ":s:t:b:p:e:T:h" opt; do
    case "$opt" in
    	s) ANDROID_SERIAL="${OPTARG}" ;;
    	t) BOOT_TIMEOUT="${OPTARG}" ;;
        b) BLACKLIST="${OPTARG}" ;;
        p) MONKEY_PARAMS="${OPTARG}" ;;
        e) EVENT_COUNT="${OPTARG}" ;;
        T) THROTTLE="${OPTARG}" ;;
        *) usage ;;
    esac
done

. "${TEST_DIR}/../../lib/sh-test-lib"
. "${TEST_DIR}/../../lib/android-test-lib"

initialize_adb
wait_boot_completed "${BOOT_TIMEOUT}"
create_out_dir "${HOST_OUTPUT}"

# Read blacklist and write to blacklist.txt
arr=$(echo "$BLACKLIST" | tr "," " ")
info_msg "--- blacklist ---"
for s in $arr
do
    echo "$s"
    echo "$s" >> "$BLACKLIST_FILE"
done

adb_push "$BLACKLIST_FILE" "/data/local/tmp/"
BLACKLIST="/data/local/tmp/blacklist.txt"

info_msg "device-${ANDROID_SERIAL}: About to run monkey..."
adb shell monkey "${MONKEY_PARAMS}" --pkg-blacklist-file "${BLACKLIST}" --throttle "${THROTTLE}" "${EVENT_COUNT}" 2>&1 \
    | tee "${LOGFILE}"

# Parse test log.
grep "Events injected: ${EVENT_COUNT}" "${LOGFILE}"
check_return "monkey-test-run"

if grep -q "Network stats: elapsed time=" "${LOGFILE}"; then
    grep "Network stats: elapsed time=" "${LOGFILE}" \
        | awk -F'=' '{print $2}' \
        | awk '{print $1}' \
        | sed 's/ms//g' \
        | awk '{printf("monkey-network-stats pass %s ms\n", $1)}' \
        | tee -a "${RESULT_FILE}"
else
    report_fail "monkey-network-stats"
fi
