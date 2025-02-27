#!/bin/sh
# signaltest is a RT signal roundtrip test software.

# shellcheck disable=SC1091
. ../../lib/sh-test-lib

OUTPUT="$(pwd)/output"
LOGFILE="${OUTPUT}/signaltest"
RESULT_FILE="${OUTPUT}/result.txt"

PRIORITY="98"
THREADS="2"
DURATION="1m"
BACKGROUND_CMD=""
ITERATIONS=1

usage() {
    echo "Usage: $0 [-r runtime] [-p priority] [-t threads] [-w background_cmd] [-i iterations]" 1>&2
    exit 1
}

while getopts ":p:t:D:w:i:" opt; do
    case "${opt}" in
        p) PRIORITY="${OPTARG}" ;;
        t) THREADS="${OPTARG}" ;;
        D) DURATION="${OPTARG}" ;;
        w) BACKGROUND_CMD="${OPTARG}" ;;
        i) ITERATIONS="${OPTARG}" ;;
        *) usage ;;
    esac
done

! check_root && error_msg "Please run this script as root."
create_out_dir "${OUTPUT}"

if [ "${THREADS}" -eq "0" ]; then
    THREADS=$(nproc)
fi

# Run signaltest.
if ! binary=$(command -v signaltest); then
    detect_abi
    # shellcheck disable=SC2154
    binary="./bin/${abi}/signaltest"
fi

background_process_start bgcmd --cmd "${BACKGROUND_CMD}"

for i in $(seq ${ITERATIONS}); do
    "${binary}" -q -D "${DURATION}" -a -m -p "${PRIORITY}" -t "${THREADS}" --json="${LOGFILE}-${i}.json"
done

background_process_stop bgcmd

# Parse test log.
for i in $(seq ${ITERATIONS}); do
    ../../lib/parse_rt_tests_results.py signaltest "${LOGFILE}-${i}.json" \
        | tee "${RESULT_FILE}"

    if [ ${ITERATIONS} -ne 1 ]; then
        sed -i "s|^|iteration-${i}-|g" "${RESULT_FILE}"
    fi
done
