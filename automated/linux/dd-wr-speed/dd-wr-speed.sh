#!/bin/sh

. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
ITERATION="5"
UNITS="MB/s"

usage() {
    echo "Usage: $0 [-p <partition>] [-t <type>] [-i <iteration>] [-s <true>]" 1>&2
    exit 1
}

while getopts "p:t:i:s:" o; do
  case "$o" in
    # The current working directory will be used by default.
    # Use '-p' specify partition that used for dd test.
    p) PARTITION="${OPTARG}" ;;
    # CAUTION: if FS_TYPE not equal to the existing fs type of the partition
    # specified with '-p', the partition will be formatted.
    t) FS_TYPE="${OPTARG}" ;;
    # You may need to run dd test 4-5 times for an accurate evaluation.
    i) ITERATION="${OPTARG}" ;;
    s) SKIP_INSTALL="${OPTARG}" ;;
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

        # If PARTITION specified, its FS_TYPE needs to be specified explicitly.
        [ -z "${FS_TYPE}" ] && error_msg "Please specify ${FS_TYPE} explicitly"

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
            | tee  -a "${OUTPUT}"/dd-write-output.txt
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
            | tee -a "${OUTPUT}"/dd-read-output.txt
    done
    rm -f dd.img
}

parse_output() {
    local test="$1"
    local test_case_id="${test}"
    if ! [ -f "${OUTPUT}/${test}-output.txt" ]; then
        warn_msg "output file is missing"
        return 1
    fi

    # Fixup test-case-id with filesystem type and partion name.
    [ -n "${FS_TYPE}" ] && test_case_id="${FS_TYPE}-${test_case_id}"
    if [ -n "${PARTITION}" ]; then
        partition_no="$(echo "${PARTITION}" |awk -F '/' '{print $NF}')"
        test_case_id="${partition_no}-${test_case_id}"
    fi

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

            add_metric "${test_case_id}-itr${itr}" "pass" "${measurement}" "${UNITS}"
            itr=$(( itr + 1 ))
        fi
    done < "${OUTPUT}/${test}-output.txt"

    # For mutiple times dd test, calculate the mean, min and max values.
    # Save them to result.txt.
    if [ "${ITERATION}" -gt 1 ]; then
        eval "$(grep "${test}" "${OUTPUT}"/result.txt \
            | awk '{
                       if(min=="") {min=max=$3};
                       if($3>max) {max=$3};
                       if($3< min) {min=$3};
                       total+=$3; count+=1;
                   }
               END {
                       print "mean="total/count, "min="min, "max="max;
                   }')"

        add_metric "${test_case_id}-mean"  "pass" "${mean}" "${UNITS}"
        add_metric "${test_case_id}-min" "pass" "${min}" "${UNITS}"
        add_metric "${test_case_id}-max" "pass" "${max}" "${UNITS}"
    fi
}

# Test run.
! check_root && error_msg "This script must be run as root"
[ -d "${OUTPUT}" ] && mv "${OUTPUT}" "${OUTPUT}_$(date +%Y%m%d%H%M%S)"
mkdir -p "${OUTPUT}"

info_msg "About to run dd test..."
info_msg "Output directory: ${OUTPUT}"

pkgs="e2fsprogs dosfstools"
install_deps "${pkgs}" "${SKIP_INSTALL}"

prepare_partition
info_msg "dd test directory: $(pwd)"
dd_write
parse_output "dd-write"
dd_read
parse_output "dd-read"
