#!/bin/sh -e
# cyclictest measures event latency in Linux kernel by measuring the amount of
# time that passes between when a timer expires and when the thread which set
# the timer actually runs.

# shellcheck disable=SC1091
. ../../lib/sh-test-lib

OUTPUT="$(pwd)/output"
LOGFILE="${OUTPUT}/cyclictest.txt"
RESULT_FILE="${OUTPUT}/result.txt"

PRIORITY="99"
INTERVAL="10000"
THREADS="1"
LOOPS="10000"

usage() {
    echo "Usage: $0 [-p priority] [-i interval] [-t threads] [-l loops]" 1>&2
    exit 1
}

while getopts ":p:i:t:l:" opt; do
    case "${opt}" in
        p) PRIORITY="${OPTARG}" ;;
        i) INTERVAL="${OPTARG}" ;;
        t) THREADS="${OPTARG}" ;;
        l) LOOPS="${OPTARG}" ;;
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
"${binary}" -p "${PRIORITY}" -i "${INTERVAL}" -t "${THREADS}" \
    -l "${LOOPS}" | tee "${LOGFILE}"

# Parse test log.
tail -n "${THREADS}" "${LOGFILE}" \
    | sed 's/T:/T: /' \
    | awk '{printf("t%s-min-latency pass %s us\n", $2, $(NF-6))};
           {printf("t%s-avg-latency pass %s us\n", $2, $(NF-2))};
           {printf("t%s-max-latency pass %s us\n", $2, $NF)};'  \
    | tee -a "${RESULT_FILE}"
