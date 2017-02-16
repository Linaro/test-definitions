#!/bin/sh -e

. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE

usage() {
    echo "Usage: $0 [-d <sda|mmcblk0>] [-s <true|false>]" 1>&2
    exit 1
}

while getopts "d:s:" o; do
  case "$o" in
    d) device_list="${OPTARG}" ;;
    s) SKIP_INSTALL="${OPTARG}" ;;
    *) usage ;;
  esac
done

! check_root && error_msg "You need to be root to run this script."
create_out_dir "${OUTPUT}"

install_deps "hdparm" "${SKIP_INSTALL}"

# Test all block devices if device not specified.
if [ -z "${device_list}" ]; then
    if lsblk | egrep "^(sd|hd|mmcblk)[a-z0-9] "; then
        device_list=$(lsblk \
                      | egrep "^(sd|hd|mmcblk)[a-z0-9] " \
                      | awk '{print $1}')
    else
        error_msg "Block device NOT found"
    fi
fi

# Test run.
# 'hdparm -t' should be repeated 2-3 times for meaningful result.
for device in ${device_list}; do
    echo
    sum=0
    for i in $(seq 3); do
       info_msg "Running iteration $i on /dev/${device}"
       output_file="${OUTPUT}/${device}-iteration$i-output.txt"
       hdparm -t /dev/"${device}" > "${output_file}" 2>&1
       result=$(grep "reads" "${output_file}" | awk '{print $(NF-1)}')
       units=$(grep "reads" "${output_file}" | awk '{print substr($NF, 1, 2)}')

       # Convert result to MB when units isn't MB.
       result=$(convert_to_mb "${result}" "${units}")

       echo "Device read timings: ${result} MB/sec"
       sum=$(echo "${sum} ${result}" | awk '{print $1+$2}')
    done

    result_avg=$(echo "${sum}" | awk '{print $1/3}')
    echo "${device} average read timings: ${result_avg}"
    add_metric "${device}-read-perf" "pass" "${result_avg}" "MB/sec"
done
