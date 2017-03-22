#!/bin/sh -ex

HOST_OUTPUT="$(pwd)/output"
LOCAL_DEVICE_OUTPUT="${HOST_OUTPUT}/device-output"
DEVICE_OUTPUT="/data/local/tmp/dd-wr-speed"
ANDROID_SERIAL=""
BOOT_TIMEOUT="300"
ITERATION="5"
PARTITION=""
RESULT_FILE="${HOST_OUTPUT}/result.txt"
export  RESULT_FILE

usage() {
    echo "Usage: $0 [-p <partition>] [-i <iteration>] [-s <android_serial>] [-t <timeout>]" 1>&2
    exit 1
}

while getopts ":p:i:s:t:" o; do
  case "$o" in
    # "/data" partition will be used by default. Use '-p' to specify an
    # external partition as needed, the partition will be formatted to vfat,
    # and all data will be lost.
    p) PARTITION="${OPTARG}" ;;
    # You may need to run dd test 4-5 times for an accurate evaluation.
    i) ITERATION="${OPTARG}" ;;
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

parse_output() {
    test_case_id="$1"
    if ! [ -f "${LOCAL_DEVICE_OUTPUT}/${test_case_id}-output.txt" ]; then
        warn_msg "${test_case_id} result file missing"
        return 1
    fi

    # Parse raw output and add results to ${RESULT_FILE}.
    itr=1
    info_msg "Parsing ${test_case_id} output..."
    while read -r line; do
        if echo "${line}" | grep -E "(M|G)B/s"; then
            # busybox dd print test result in the format "39.8MB/s".
            units=$(echo "${line}" | awk '{print substr($NF,(length($NF)-3),2)}')
            measurement=$(echo "${line}" | awk '{print substr($NF,1,(length($NF)-4))}')
            measurement=$(convert_to_mb "${measurement}" "${units}")
            add_metric "${test_case_id}-itr${itr}" "pass" "${measurement}" "MB/s"
            itr=$(( itr + 1 ))
        fi
    done < "${LOCAL_DEVICE_OUTPUT}/${test_case_id}"-output.txt

    # For multiple times dd test, calculate the mean, min and max values.
    # Save them to ${RESULT_FILE}.
    if [ "${ITERATION}" -gt 1 ]; then
        eval "$(grep "${test_case_id}" "${HOST_OUTPUT}"/result.txt \
            | awk '{
                       if(min=="") {min=max=$3};
                       if($3>max) {max=$3};
                       if($3< min) {min=$3};
                       total+=$3; count+=1;
                   }
               END {
                       print "mean="total/count, "min="min, "max="max;
                   }')"

        # shellcheck disable=SC2154
        add_metric "${test_case_id}-mean" "pass" "${mean}" "MB/s"
        # shellcheck disable=SC2154
        add_metric "${test_case_id}-min" "pass" "${min}" "MB/s"
        # shellcheck disable=SC2154
        add_metric "${test_case_id}-max" "pass" "${max}" "MB/s"
    fi
}

# Test run.
create_out_dir "${HOST_OUTPUT}"
mkdir -p "${LOCAL_DEVICE_OUTPUT}"

initialize_adb
wait_boot_completed "${BOOT_TIMEOUT}"

detect_abi
# shellcheck disable=SC2154
adb_push  "../../bin/${abi}/busybox" "/data/local/tmp/bin/"
adb_push "./device-script.sh" "/data/local/tmp/bin"

info_msg "About to run dd speed test on device ${ANDROID_SERIAL}"
adb shell "echo /data/local/tmp/bin/device-script.sh ${ITERATION} ${DEVICE_OUTPUT} ${PARTITION} | su" 2>&1 | tee "${HOST_OUTPUT}/device-stdout.log"

adb_pull "${DEVICE_OUTPUT}" "${LOCAL_DEVICE_OUTPUT}"

parse_output "dd-write"
parse_output "dd-read"
