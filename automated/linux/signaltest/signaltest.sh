#!/bin/sh -e
# signaltest is a RT signal roundtrip test software.

# shellcheck disable=SC1091
. ../../lib/sh-test-lib

OUTPUT="$(pwd)/output"
LOGFILE="${OUTPUT}/signaltest.txt"
RESULT_FILE="${OUTPUT}/result.txt"

PRIORITY="98"
THREADS="2"
MAX_LATENCY="100"
DURATION="1m"

usage() {
    echo "Usage: $0 [-r runtime] [-p priority] [-t threads] [-m latency]" 1>&2
    exit 1
}

while getopts ":p:t:D:m:" opt; do
    case "${opt}" in
        p) PRIORITY="${OPTARG}" ;;
        t) THREADS="${OPTARG}" ;;
	D) DURATION="${OPTARG}" ;;
	m) MAX_LATENCY="${OPTARG}" ;;
        *) usage ;;
    esac
done

! check_root && error_msg "Please run this script as root."
create_out_dir "${OUTPUT}"

# Run signaltest.
if ! binary=$(which signaltest); then
    detect_abi
    # shellcheck disable=SC2154
    binary="./bin/${abi}/signaltest"
fi

"${binary}" -D "${DURATION}" -m -p "${PRIORITY}" -t "${THREADS}" \
    | tee "${LOGFILE}"

# Parse test log.
../../lib/parse_rt_tests_results.py signaltest "${LOGFILE}" "${MAX_LATENCY}" \
    | tee -a "${RESULT_FILE}"
