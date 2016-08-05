#!/bin/sh
#
# Run dd write/read speed test.
#
# Copyright (C) 2010 - 2016, Linaro Limited.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# Author: Chase Qi <chase.qi@linaro.org>

. ./common/scripts/include/sh-test-lib
LANG=C
export LANG
WD="$(pwd)"
RESULT_FILE="${WD}/result.txt"
ITERATION="5"
UNITS="MB/s"

usage() {
    echo "Usage: $0 [-p <partition>] [-t <type>] [-i <iteration>]" 1>&2
    exit 1
}

while getopts "p:t:i:" o; do
  case "$o" in
    # The current working directory will be used by default.
    # Use '-p' specify partition that used for dd test.
    p) PARTITION="${OPTARG}" ;;
    # CAUTION: if FS_TYPE not equal to the existing fs type of the partition
    # specified with '-p', the partition will be formatted.
    t) FS_TYPE="${OPTARG}" ;;
    # You may need to run dd test 4-5 times for an accurate evaluation.
    i) ITERATION="${OPTARG}" ;;
    *) usage ;;
  esac
done

prepare_partition() {
    if [ -n "${PARTITION}" ]; then
        device_attribute="$(blkid | grep "${PARTITION}")"
        [ -z "${device_attribute}" ] && error_msg "${PARTITION} NOT found"
        fs_type=$(echo "${device_attribute}" \
            | grep "TYPE=" \
            | awk '{print $3}' \
            | awk -F '"' '{print $2}')

        # Try to format the partition if it is unformatted or not the same as
        # the filesystem type specified with parameter '-t'.
        if [ -n "${FS_TYPE}" ]; then
            if [ "${FS_TYPE}" != "${fs_type}" ]; then
                umount "${PARTITION}" > /dev/null 2>&1
                info_msg "Formatting ${PARTITION} to ${FS_TYPE}..."

                if [ "${FS_TYPE}" = "fat32" ]; then
                    echo "y" | mkfs -t vfat -F 32 "${PARTITION}"
                else
                    echo "y" | mkfs -t "${FS_TYPE}" "${PARTITION}"
                fi

                if [ $? -ne 0 ]; then
                    error_msg "unable to format ${PARTITION}"
                else
                    info_msg "${PARTITION} formatted to ${FS_TYPE}"
                fi
            fi
        fi

         # Mount the partition and enter its mount point.
         mount_point="$(df |grep "${PARTITION}" | awk '{print $NF}')"
         if [ -z "${mount_point}" ]; then
             mount_point="/mnt"
             mount "${PARTITION}" "${mount_point}"
             if [ $? -ne 0 ]; then
                 error_msg "Unable to mount ${PARTITIOIN}"
             else
                 info_msg "${PARTITION} mounted to ${mount_point}"
             fi
         fi
         cd "${mount_point}"
    fi
}

dd_write() {
    echo
    echo "--- dd write speed test ---"
    rm -f dd-write-output.txt
    for i in $(seq "${ITERATION}"); do
        echo "Running iteration ${i}..."
        rm -f dd.img
        echo 3 > /proc/sys/vm/drop_caches
        dd if=/dev/zero of=dd.img bs=1048576 count=1024 conv=fsync 2>&1 \
            | tee  -a "${WD}"/dd-write-output.txt
    done
}

dd_read() {
    echo
    echo "--- dd read speed test ---"
    rm -f dd-read-output.txt
    for i in $(seq "${ITERATION}"); do
        echo "Running iteration ${i}..."
        echo 3 > /proc/sys/vm/drop_caches
        dd if=dd.img of=/dev/null bs=1048576 count=1024 2>&1 \
            | tee -a "${WD}"/dd-read-output.txt
    done
    rm -f dd.img
}

parse_output() {
    local test="$1"
    local test_case_id="${test}"
    [ -n "${FS_TYPE}" ] && test_case_id="${FS_TYPE}-${test_case_id}"
    if [ -n "${PARTITION}" ]; then
        partition_no="$(echo "${PARTITION}" |awk -F '/' '{print $NF}')"
        test_case_id="${partition_no}-${test_case_id}"
    fi

    # Parse raw output and add results to result.txt.
    itr=1
    while read line; do
        if echo "${line}" | egrep -q "(M|G)B/s"; then
            measurement="$(echo "${line}" | awk '{print $(NF-1)}')"
            units="$(echo "${line}" | awk '{print $NF}')"

            if [ "${units}" = "GB/s" ]; then
                measurement=$(( measurement * 1024 ))
            elif [ "${units}" = "KB/s" ]; then
                measurement=$(( measurement / 1024 ))
            fi

            add_metric "${test_case_id}-itr${itr}" "${measurement}" "${UNITS}"
            itr=$(( itr + 1 ))
        fi
    done < "${WD}/${test}"-output.txt

    # For mutiple times dd test, calculate the mean, min and max values.
    # Save them to result.txt.
    if [ "${ITERATION}" -gt 1 ]; then
        eval "$(grep "${test}" "${WD}"/result.txt \
            | awk '{
                       if(min=="") {min=max=$3};
                       if($3>max) {max=$3};
                       if($3< min) {min=$3};
                       total+=$3; count+=1;
                   }
               END {
                       print "mean="total/count, "min="min, "max="max;
                   }')"

        add_metric "${test_case_id}-mean" "${mean}" "${UNITS}"
        add_metric "${test_case_id}-min" "${min}" "${UNITS}"
        add_metric "${test_case_id}-max" "${max}" "${UNITS}"
    fi
}

# Test run.
! check_root && error_msg "This script must be run as root"

pkgs="e2fsprogs dosfstools"
install_deps "${pkgs}"

[ -f "${RESULT_FILE}" ] && \
mv "${RESULT_FILE}" "${RESULT_FILE}_$(date +%Y%m%d%H%M%S)"
echo
info_msg "About to run dd test..."
info_msg "Working directory: ${WD}"
info_msg "Result will be saved to: ${RESULT_FILE}"

prepare_partition
info_msg "dd test directory: $(pwd)"
dd_write
parse_output "dd-write"
dd_read
parse_output "dd-read"
