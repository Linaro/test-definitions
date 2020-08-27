#!/bin/sh -e
# cyclictest measures event latency in Linux kernel by measuring the amount of
# time that passes between when a timer expires and when the thread which set
# the timer actually runs.

# shellcheck disable=SC1091
. ../../lib/sh-test-lib

OUTPUT="$(pwd)/output"
LOGFILE="${OUTPUT}/cyclictest.txt"
RESULT_FILE="${OUTPUT}/result.txt"

PRIORITY="98"
INTERVAL="1000"
THREADS="1"
AFFINITY="0"
DURATION="1m"
MAX_LATENCY="50"

usage() {
    echo "Usage: $0 [-p priority] [-i interval] [-t threads] [-a affinity] [-D duration ] [-m latency]" 1>&2
    exit 1
}

while getopts ":p:i:t:a:D:m:" opt; do
    case "${opt}" in
        p) PRIORITY="${OPTARG}" ;;
        i) INTERVAL="${OPTARG}" ;;
        t) THREADS="${OPTARG}" ;;
	a) AFFINITY="${OPTARG}" ;;
        D) DURATION="${OPTARG}" ;;
	m) MAX_LATENCY="${OPTARG}" ;;
        *) usage ;;
    esac
done

! check_root && error_msg "Please run this script as root."
create_out_dir "${OUTPUT}"

# Run cyclictest.
if ! binary=$(which cyclictest); then
    detect_abi
    # shellcheck disable=SC2154
    binary="./bin/${abi}/cyclictest"
fi
"${binary}" -q -p "${PRIORITY}" -i "${INTERVAL}" -t "${THREADS}" -a "${AFFINITY}" \
    -D "${DURATION}" -m | tee "${LOGFILE}"

# Parse test log.
../../lib/parse_rt_tests_results.py cyclictest "${LOGFILE}" "${MAX_LATENCY}" \
    | tee -a "${RESULT_FILE}"
