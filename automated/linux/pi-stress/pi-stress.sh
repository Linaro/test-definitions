#!/bin/sh
# pi_stress checks Priority Inheritence Mutexes and their ability to avoid
# Priority Inversion from occuring by running groups of threads that cause
# Priority Inversions.

# shellcheck disable=SC1091
. ../../lib/sh-test-lib

OUTPUT="$(pwd)/output"
LOGFILE="${OUTPUT}/pi-stress"
RESULT_FILE="${OUTPUT}/result.txt"
TMP_RESULT_FILE="${OUTPUT}/tmp_result.txt"
export RESULT_FILE

DURATION="5m"
MLOCKALL="false"
RR="false"
BACKGROUND_CMD=""
ITERATIONS=1

usage() {
    echo "Usage: $0 [-D runtime] [-m <true|false>] [-r <true|false>] [-w background_cmd] [-i iterations]" 1>&2
    exit 1
}

while getopts ":D:m:r:w:i:" opt; do
    case "${opt}" in
        D) DURATION="${OPTARG}" ;;
        m) MLOCKALL="${OPTARG}" ;;
        r) RR="${OPTARG}" ;;
        w) BACKGROUND_CMD="${OPTARG}" ;;
        i) ITERATIONS="${OPTARG}" ;;
        *) usage ;;
    esac
done

! check_root && error_msg "Please run this script as root."
create_out_dir "${OUTPUT}"

if "${MLOCKALL}"; then
    MLOCKALL="--mlockall"
else
    MLOCKALL=""
fi
if "${RR}"; then
    RR="--rr"
else
    RR=""
fi

if ! binary=$(command -v pi_stress); then
    detect_abi
    # shellcheck disable=SC2154
    binary="./bin/${abi}/pi_stress"
fi

background_process_start bgcmd --cmd "${BACKGROUND_CMD}"

# pi_stress will send SIGTERM when test fails. The signal will terminate the
# test script. Catch and ignore it with trap.
trap '' TERM
# shellcheck disable=SC2086
for i in $(seq ${ITERATIONS}); do
    "${binary}" -q --duration "${DURATION}" ${MLOCKALL} ${RR} --json="${LOGFILE}-${i}.json"
done

background_process_stop bgcmd

# Parse test log.
for i in $(seq ${ITERATIONS}); do
    ../../lib/parse_rt_tests_results.py pi-stress "${LOGFILE}-${i}.json" \
        | tee "${TMP_RESULT_FILE}"

    if [ ${ITERATIONS} -ne 1 ]; then
        sed -i "s|^|iteration-${i}-|g" "${TMP_RESULT_FILE}"
    fi
    cat "${TMP_RESULT_FILE}" | tee -a "${RESULT_FILE}"
done
