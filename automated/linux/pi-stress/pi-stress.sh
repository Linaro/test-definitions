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
USER_BASELINE=""

usage() {
    echo "Usage: $0 [-D runtime] [-m <true|false>] [-r <true|false>] [-w background_cmd] [-i iterations] [-x user baseline]" 1>&2
    exit 1
}

while getopts ":D:m:r:w:i:x:" opt; do
    case "${opt}" in
        D) DURATION="${OPTARG}" ;;
        m) MLOCKALL="${OPTARG}" ;;
        r) RR="${OPTARG}" ;;
        w) BACKGROUND_CMD="${OPTARG}" ;;
        i) ITERATIONS="${OPTARG}" ;;
        x) USER_BASELINE="${OPTARG}" ;;
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

if [ "${ITERATIONS}" -gt 2 ]; then
    max_inversions_file="${OUTPUT}/max_inversions.txt"

    # Extract all inversion values into a file
    grep "inversion" "${RESULT_FILE}" | grep "^iteration-" | awk '{ print $(NF-1) }' |tee "${max_inversions_file}"

    if [ ! -s "${max_inversions_file}" ]; then
        echo "No inversion values found!"
        report_fail "rt-tests-pi-stress"
        exit 1
    fi

    # Find the minimum inversion
    if [ -n "${USER_BASELINE}" ]; then
        max_inversion="${USER_BASELINE}"
        echo "Using user-provided user_baseline: ${max_inversion}"
    else
        max_inversion=$(sort -n "${max_inversions_file}" | tail -n1)
        echo "Calculated max_inversion: ${max_inversion}"
    fi

    fail_count=0
    while read -r val; do
        is_less=$(echo "$val < $max_inversion" | bc -l)
        if [ "$is_less" -eq 1 ]; then
            fail_count=$((fail_count + 1))
        fi
    done < "${max_inversions_file}"

    fail_limit=$((ITERATIONS / 2))

    echo "Max allowed failures: $fail_limit"
    echo "Actual failures: $fail_count"

    if [ "$fail_count" -ge "$fail_limit" ]; then
        report_fail "rt-tests-pi-stress"
    else
        report_pass "rt-tests-pi-stress"
    fi
fi
