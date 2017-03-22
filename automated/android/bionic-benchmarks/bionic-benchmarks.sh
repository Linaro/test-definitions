#!/bin/sh

HOST_OUTPUT="$(pwd)/output"
DEVICE_OUTPUT="/data/local/tmp/result_unsorted.txt"
RESULT_FILE="${HOST_OUTPUT}/result.txt"
export RESULT_FILE
LOOPS=1
TIMEOUT=300

usage() {
    echo "Usage: $0 [-l <loops count>]" 1>&2
    exit 1
}

report_test() {
    test_key=$1 sum=$2 loops=$3 units=$4

    avg=$((sum / loops))
    echo "${test_key} pass ${avg} ${units}"
}

consolidate_results() {
    # Sort timed tests by name
    grep _time "${HOST_OUTPUT}/result_unsorted.txt" | sort > "${HOST_OUTPUT}/result_sorted.txt"

    # Count and calculate average for each timed test
    while read -r testres; do
        test=$(echo "${testres}"   | awk '{print $1}')
        value=$(echo "${testres}"  | awk '{print $3}')
        units=$(echo "${testres}"  | awk '{print $4}')

        if [ "${test}" != "${curr_test}" ]; then
            if [ -n "${curr_test}" ]; then
                report_test "${curr_test}" "${sum}" "${LOOPS}" "${units}" >> \
                    "${RESULT_FILE}"
            fi
            curr_test="${test}"
            sum=${value}
        else
            sum=$((sum + value))
        fi
    done < "${HOST_OUTPUT}/result_sorted.txt"
    # Last test from the loop:
    report_test "${curr_test}" "${sum}" "${LOOPS}" "${units}" >> "${RESULT_FILE}"

    # Add non-timed tests to result.txt
    grep -v _time "${HOST_OUTPUT}/result_unsorted.txt" | sort -u >> "${RESULT_FILE}"
}

while getopts "l:" o; do
  case "$o" in
    # Number of times the benchmarks will run.
    l) LOOPS="${OPTARG}" ;;
    *) usage ;;
  esac
done

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
. ../../lib/android-test-lib

# Test run.
create_out_dir "${HOST_OUTPUT}"

initialize_adb
wait_boot_completed "${TIMEOUT}"
adb_push "./device-script.sh" "/data/local/tmp/"

info_msg "About to run bionic-benchmarks on device ${ANDROID_SERIAL}"
adb shell /data/local/tmp/device-script.sh "${LOOPS}" 2>&1 \
    | tee "${HOST_OUTPUT}"/device-run.log

adb_pull "${DEVICE_OUTPUT}" "${HOST_OUTPUT}"

if [ "${LOOPS}" -gt 1 ]; then
    consolidate_results
else
    cp -p "${HOST_OUTPUT}/result_unsorted.txt" "${RESULT_FILE}"
fi
