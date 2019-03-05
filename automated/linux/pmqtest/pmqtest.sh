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
MAX_LATENCY="100"

usage() {
    echo "Usage: $0 [-l loops] [-m latency]" 1>&2
    exit 1
}

while getopts ":l:m:" opt; do
    case "${opt}" in
        l) LOOPS="${OPTARG}" ;;
	m) MAX_LATENCY="${OPTARG}" ;;
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
../../lib/parse_rt_tests_results.py pmqtest "${LOGFILE}" "${MAX_LATENCY}" \
    | tee -a "${RESULT_FILE}"
