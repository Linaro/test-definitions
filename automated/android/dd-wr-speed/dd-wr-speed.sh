#!/bin/sh

HOST_OUTPUT="$(pwd)/output"
DEVICE_OUTPUT="/sdcard/tests/dd-wr-speed"
RESULT_FILE="${HOST_OUTPUT}/result.txt"
ITERATION="5"
PARTITION=""

usage() {
    echo "Usage: $0 [-p <partition>] [-i <iteration>] [-s <sn>]" 1>&2
    exit 1
}

while getopts "p:i:s:" o; do
  case "$o" in
    # "/data" partition will be used by default. Use '-p' to specify an
    # external partition as needed, the partition will be formatted to vfat,
    # and all data will be lost.
    p) PARTITION="${OPTARG}" ;;
    # You may need to run dd test 4-5 times for an accurate evaluation.
    i) ITERATION="${OPTARG}" ;;
    # Specify device serial number when more than one device connected.
    s) SN="${OPTARG}" ;;
    *) usage ;;
  esac
done

. ../../lib/sh-test-lib
. ../../lib/android-test-lib

parse_output() {
    local test="$1"
    local test_case_id="${test}"
    local UNITS="MB/s"

    if ! [ -f "${HOST_OUTPUT}/${test}-output.txt" ]; then
        warn_msg "${test} result file missing"
        return
    fi

    # Fixup test case id with partition and filesystem.
    if [ -n "${PARTITION}" ]; then
        partition_name="$(basename "${PARTITION}")"
        test_case_id="${partition_name}-vfat-${test_case_id}"
    else
        filesystem="$(adb -s "${SN}" shell mount \
            | grep "/data" | awk '{print $3}')"
        test_case_id="emmc-${filesystem}-${test_case_id}"
    fi

    # Parse raw output and add results to ${RESULT_FILE}.
    itr=1
    info_msg "Parsing ${test} output..."
    while read line; do
        if echo "${line}" | egrep -q "(M|G)B/s"; then
            # busybox dd print test result in the format "39.8MB/s".
            result="$(echo "${line}" | awk '{print $NF}')"
            units="$(printf "%s" "${result}" | tail -c 4)"
            measurement="$(printf "%s" "${result}" | tr -d "${units}")"

            if [ "${units}" = "GB/s" ]; then
                measurement=$(( measurement * 1024 ))
            elif [ "${units}" = "KB/s" ]; then
                measurement=$(( measurement / 1024 ))
            fi

            add_metric "${test_case_id}-itr${itr}" "pass" "${measurement}" "${UNITS}"
            itr=$(( itr + 1 ))
        fi
    done < "${HOST_OUTPUT}/${test}"-output.txt

    # For multiple times dd test, calculate the mean, min and max values.
    # Save them to ${RESULT_FILE}.
    if [ "${ITERATION}" -gt 1 ]; then
        eval "$(grep "${test}" "${HOST_OUTPUT}"/result.txt \
            | awk '{
                       if(min=="") {min=max=$3};
                       if($3>max) {max=$3};
                       if($3< min) {min=$3};
                       total+=$3; count+=1;
                   }
               END {
                       print "mean="total/count, "min="min, "max="max;
                   }')"

        add_metric "${test_case_id}-mean" "pass" "${mean}" "${UNITS}"
        add_metric "${test_case_id}-min" "pass" "${min}" "${UNITS}"
        add_metric "${test_case_id}-max" "pass" "${max}" "${UNITS}"
    fi
}

# Test run.
[ -d "${HOST_OUTPUT}" ] && mv "${HOST_OUTPUT}" "${HOST_OUTPUT}-$(date +%Y%m%d%H%M%S)"
mkdir -p "${HOST_OUTPUT}"

initialize_adb
detect_abi
install "../../bin/${abi}/busybox"
install "./device-script.sh"

info_msg "About to run dd speed test on device ${SN}"
adb -s "${SN}" shell device-script.sh "${ITERATION}" "${PARTITION}" "${DEVICE_OUTPUT}" 2>&1 \
    | tee "${HOST_OUTPUT}"/device-run.log

pull_output "${DEVICE_OUTPUT}" "${HOST_OUTPUT}"

parse_output "dd-write"
parse_output "dd-read"
