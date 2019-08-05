#!/bin/sh -e
# shellcheck disable=SC1090
# shellcheck disable=SC2154
# sigwaittest starts two threads or, optionally, forks two processes that
# are synchronized via signals and measures the latency between sending
# a signal and returning from sigwait()

TEST_DIR=$(dirname "$(realpath "$0")")
OUTPUT="${TEST_DIR}/output"
LOGFILE="${OUTPUT}/sigwaittest.log"
RESULT_FILE="${OUTPUT}/result.txt"
DURATION="5m"
MAX_LATENCY="100"

usage() {
    echo "Usage: $0 [-D duration] [-m latency]" 1>&2
    exit 1
}

while getopts ":D:m:" opt; do
    case "${opt}" in
        D) DURATION="${OPTARG}" ;;
	m) MAX_LATENCY="${OPTARG}" ;;
        *) usage ;;
    esac
done

. "${TEST_DIR}/../../lib/sh-test-lib"

! check_root && error_msg "Please run this script as root."
create_out_dir "${OUTPUT}"

# Run sigwaittest.
if ! binary=$(command -v sigwaittest); then
    detect_abi
    # shellcheck disable=SC2154
    binary="./bin/${abi}/sigwaittest"
fi

"${binary}" -t -a -p 98 -D "${DURATION}" | tee "${LOGFILE}"

# Parse test log.
../../lib/parse_rt_tests_results.py sigwaittest "${LOGFILE}" "${MAX_LATENCY}" \
    | tee -a "${RESULT_FILE}"
