#!/bin/sh -e
# cyclicdeadline is a test that is similar to cyclictest but instead
# of using SCHED_FIFO and nanosleep() to measure jitter, it uses
# SCHED_DEADLINE and has the deadline be the wakeup interval."

# shellcheck disable=SC1091
. ../../lib/sh-test-lib

OUTPUT="$(pwd)/output"
LOGFILE="${OUTPUT}/cyclicdeadline.json"
RESULT_FILE="${OUTPUT}/result.txt"

INTERVAL="1000"
STEP="500"
THREADS="1"
DURATION="1m"
BACKGROUND_CMD=""

usage() {
    echo "Usage: $0 [-i interval] [-s step] [-t threads] [-D duration ] [-w background_cmd]" 1>&2
    exit 1
}

while getopts ":i:s:t:D:w:" opt; do
    case "${opt}" in
        i) INTERVAL="${OPTARG}" ;;
        s) STEP="${OPTARG}" ;;
        t) THREADS="${OPTARG}" ;;
        D) DURATION="${OPTARG}" ;;
        w) BACKGROUND_CMD="${OPTARG}" ;;
        *) usage ;;
    esac
done

! check_root && error_msg "Please run this script as root."
create_out_dir "${OUTPUT}"

if [ "${THREADS}" -eq "0" ]; then
    THREADS=$(nproc)
fi

# Run cyclicdeadline.
if ! binary=$(command -v cyclicdeadline); then
    detect_abi
    # shellcheck disable=SC2154
    binary="./bin/${abi}/cyclicdeadline"
fi

background_process_start bgcmd --cmd "${BACKGROUND_CMD}"

"${binary}" -q -i "${INTERVAL}" -s "${STEP}" -t "${THREADS}" \
	-D "${DURATION}" --json="${LOGFILE}"

background_process_stop bgcmd

# Parse test log.
../../lib/parse_rt_tests_results.py cyclicdeadline "${LOGFILE}" \
    | tee -a "${RESULT_FILE}"
