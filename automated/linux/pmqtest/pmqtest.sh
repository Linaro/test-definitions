#!/bin/sh -e
# shellcheck disable=SC1090
# shellcheck disable=SC2154
# pmqtest start pairs of threads and measure the latency of interprocess
# communication with POSIX messages queues.

TEST_DIR=$(dirname "$(realpath "$0")")
OUTPUT="${TEST_DIR}/output"
LOGFILE="${OUTPUT}/pmqtest"
RESULT_FILE="${OUTPUT}/result.txt"
DURATION="5m"
BACKGROUND_CMD=""
ITERATIONS=1

usage() {
    echo "Usage: $0 [-D duration] [-w background_cmd] [-i iterations]" 1>&2
    exit 1
}

while getopts ":D:w:i:" opt; do
    case "${opt}" in
        D) DURATION="${OPTARG}" ;;
        w) BACKGROUND_CMD="${OPTARG}" ;;
        i) ITERATIONS="${OPTARG}" ;;
        *) usage ;;
    esac
done

. "${TEST_DIR}/../../lib/sh-test-lib"

! check_root && error_msg "Please run this script as root."
create_out_dir "${OUTPUT}"

# Run pmqtest.
if ! binary=$(command -v pmqtest); then
    detect_abi
    # shellcheck disable=SC2154
    binary="./bin/${abi}/pmqtest"
fi

background_process_start bgcmd --cmd "${BACKGROUND_CMD}"

for i in $(seq ${ITERATIONS}); do
    "${binary}" -q -S -p 98 -D "${DURATION}" --json="${LOGFILE}-${i}.json"
done

background_process_stop bgcmd

# Parse test log.
for i in $(seq ${ITERATIONS}); do
    ../../lib/parse_rt_tests_results.py pmqtest "${LOGFILE}-${i}.json" \
        | tee "${RESULT_FILE}"

    if [ ${ITERATIONS} -ne 1 ]; then
        sed -i "s|^|iteration-${i}-|g" "${RESULT_FILE}"
    fi
done
