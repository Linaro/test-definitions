#!/bin/sh -e
# signaltest is a RT signal roundtrip test software.

# shellcheck disable=SC1091
. ../../lib/sh-test-lib

OUTPUT="$(pwd)/output"
LOGFILE="${OUTPUT}/signaltest.txt"
RESULT_FILE="${OUTPUT}/result.txt"

PRIORITY="99"
THREADS="2"
LOOPS="10000"

usage() {
    echo "Usage: $0 [-p priority] [-t threads] [-l loops]" 1>&2
    exit 1
}

while getopts ":p:t:l:" opt; do
    case "${opt}" in
        p) PRIORITY="${OPTARG}" ;;
        t) THREADS="${OPTARG}" ;;
        l) LOOPS="${OPTARG}" ;;
        *) usage ;;
    esac
done

! check_root && error_msg "Please run this script as root."
[ -d "${OUTPUT}" ] && mv "${OUTPUT}" "${OUTPUT}_$(date +%Y%m%d%H%M%S)"
mkdir -p "${OUTPUT}"

# Run signaltest.
detect_abi
# shellcheck disable=SC2154
./bin/"${abi}"/signaltest -p "${PRIORITY}" -t "${THREADS}" -l "${LOOPS}" \
    | tee "${LOGFILE}"

# Parse test log.
tail -n 1 "${LOGFILE}" \
    | awk '{printf("min-latency pass %s us\n", $(NF-6))};
           {printf("avg-latency pass %s us\n", $(NF-2))};
           {printf("max-latency pass %s us\n", $NF)};'  \
    | tee -a "${RESULT_FILE}"
