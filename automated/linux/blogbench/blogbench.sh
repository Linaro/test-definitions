#!/bin/sh -e

. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
LOG_FILE="${OUTPUT}/blogbench.txt"
ITERATION="30"
PARTITION=""

usage() {
    echo "Usage: $0 [-i <iterations>] [-p </dev/sda1>]" 1>&2
    exit 1
}

while getopts "i:p:h" o; do
    case "$o" in
        i) ITERATION="${OPTARG}" ;;
        p) PARTITION="${OPTARG}" ;;
        h|*) usage ;;
    esac
done

! check_root && error_msg "You need to be root to run this script."
create_out_dir "${OUTPUT}"

# Set the directory for blogbench test.
if [ -n "${PARTITION}" ]; then
    if mount | grep -q "${PARTITION}"; then
        mount "${PARTITION}" /mnt
        cd /mnt/
    else
        mount_point=$(mount | grep "${PARTITION}" | awk '{print $3}')
        cd "${mount_point}"
    fi
fi
mkdir ./bench

# Run blogbench test.
detect_abi
# shellcheck disable=SC2154
./bin/"${abi}"/blogbench -i "${ITERATION}" -d ./bench 2>&1 | tee "${LOG_FILE}"

# Parse test result.
for i in writes reads; do
    grep "Final score for $i" "${LOG_FILE}" \
        | awk -v i="$i" '{printf("blogbench-%s pass %s blogs\n", i, $NF)}' \
        | tee -a "${RESULT_FILE}"
done

rm -rf ./bench
