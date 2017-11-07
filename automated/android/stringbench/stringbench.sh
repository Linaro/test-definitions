#!/bin/sh -ex

OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE
ANDROID_SERIAL=""
BOOT_TIMEOUT="300"

usage() {
    echo "Usage: $0 [-s <android_serial>] [-t <boot_timeout>]" 1>&2
    exit 1
}

while getopts ":s:t:" o; do
  case "$o" in
    # Specify device serial number when more than one device connected.
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

parser() {
    logfile="$1"
    case "$2" in
        stringbench) prefix="32bit" ;;
        stringbench64) prefix="64bit" ;;
    esac

    while read -r line; do
        test_case_id=$(echo "${line}" | cut -d: -f1 | tr -c '[:alnum:]:.' '_' | tr -s '_' | sed 's/_$//')
        test_case_id="${prefix}_${test_case_id}"
        measurement=$(echo "${line}" | awk '{print $(NF-1)}')
        units=$(echo "${line}" | awk '{print $NF}')
        add_metric "${test_case_id}" "pass" "${measurement}" "${units}"
    done < "${logfile}"
}

if ! adb_shell_which "stringbench" && ! adb_shell_which "stringbench64"; then
    report_fail "check_cmd_existence"
    exit 1
fi

for test in stringbench stringbench64; do
    info_msg "device-${ANDROID_SERIAL}: About to run ${test}"
    if ! adb_shell_which "${test}"; then
        continue
    fi
    adb shell "${test}" | tee "${OUTPUT}/${test}.log"
    parser "${OUTPUT}/${test}.log" "${test}"
done
