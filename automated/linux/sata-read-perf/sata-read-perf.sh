#!/bin/sh

. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE

usage() {
    echo "Usage: $0 [-s <true|false>]" 1>&2
    exit 1
}

while getopts "s:" o; do
  case "$o" in
    s) SKIP_INSTALL="${OPTARG}" ;;
    *) usage ;;
  esac
done

! check_root && error_msg "You need to be root to run this script."
[ -d "${OUTPUT}" ] && mv "${OUTPUT}" "${OUTPUT}_$(date +%Y%m%d%H%M%S)"
mkdir -p "${OUTPUT}"

install_deps "hdparm" "${SKIP_INSTALL}"

# Check if SATA/IDE device exists.
info_msg "Checking block device..."
if lsblk | egrep "^sd.*disk"; then
    disk_list=$(lsblk | egrep "^sd.*disk" | awk '{print $1}')
else
    error_msg "SATA/IDE device NOT found"
    exit 0
fi

# Test run.
# 'hdparm -t' should be repeated 2-3 times for meaningful result.
for disk in ${disk_list}; do
    echo
    sum=0
    for i in $(seq 3); do
       info_msg "Running iteration $i on /dev/${disk}"
       output_file="${OUTPUT}/${disk}-iteration$i-output.txt"
       hdparm -t /dev/"${disk}" > "${output_file}" 2>&1
       result=$(grep "reads" "${output_file}" | awk '{print $(NF-1)}')
       units=$(grep "reads" "${output_file}" | awk '{print substr($NF, 1, 2)}')

       # Convert result to MB when units isn't MB.
       result=$(convert_to_mb "${result}" "${units}")

       echo "Device read timings: ${result} MB/sec"
       sum=$(echo "${sum} ${result}" | awk '{print $1+$2}')
    done

    result_avg=$(echo "${sum}" | awk '{print $1/3}')
    echo "${disk} average read timings: ${result_avg}"
    add_metric "${disk}-read-perf" "pass" "${result_avg}" "MB/sec"
done
