#!/bin/sh -e
# shellcheck disable=SC1090
# shellcheck disable=SC2154
# pmqtest start pairs of threads and measure the latency of interprocess
# communication with POSIX messages queues.

TEST_DIR=$(dirname "$(realpath "$0")")
OUTPUT="${TEST_DIR}/output"
LOGFILE="${OUTPUT}/pmqtest.log"
RESULT_FILE="${OUTPUT}/result.txt"
LOOPS="10000"

usage() {
    echo "Usage: $0 [-l loops]" 1>&2
    exit 1
}

while getopts ":l:" opt; do
    case "${opt}" in
        l) LOOPS="${OPTARG}" ;;
        *) usage ;;
    esac
done

. "${TEST_DIR}/../../lib/sh-test-lib"

! check_root && error_msg "Please run this script as root."
create_out_dir "${OUTPUT}"

# Run pmqtest.
if ! binary=$(which pmqtest); then
    detect_abi
    # shellcheck disable=SC2154
    binary="./bin/${abi}/pmqtest"
fi

"${binary}" -S -l "${LOOPS}" | tee "${LOGFILE}"

# Parse test log.
tail -n "$(nproc)" "${LOGFILE}" \
    | sed 's/,//g' \
    | awk '{printf("t%s-min-latency pass %s us\n", NR, $(NF-6))};
           {printf("t%s-avg-latency pass %s us\n", NR, $(NF-2))};
           {printf("t%s-max-latency pass %s us\n", NR, $NF)};'  \
    | tee -a "${RESULT_FILE}"
