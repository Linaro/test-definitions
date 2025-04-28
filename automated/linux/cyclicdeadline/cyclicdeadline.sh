#!/bin/sh -e
# cyclicdeadline is a test that is similar to cyclictest but instead
# of using SCHED_FIFO and nanosleep() to measure jitter, it uses
# SCHED_DEADLINE and has the deadline be the wakeup interval."

# shellcheck disable=SC1091
. ../../lib/sh-test-lib

OUTPUT="$(pwd)/output"
LOGFILE="${OUTPUT}/cyclicdeadline"
RESULT_FILE="${OUTPUT}/result.txt"
TMP_RESULT_FILE="${OUTPUT}/tmp_result.txt"

INTERVAL="1000"
STEP="500"
THREADS="1"
DURATION="1m"
BACKGROUND_CMD=""
ITERATIONS=1

usage() {
    echo "Usage: $0 [-i interval] [-s step] [-t threads] [-D duration ] [-w background_cmd] [-I iterations]" 1>&2
    exit 1
}

while getopts ":i:s:t:D:w:I:" opt; do
    case "${opt}" in
        i) INTERVAL="${OPTARG}" ;;
        s) STEP="${OPTARG}" ;;
        t) THREADS="${OPTARG}" ;;
        D) DURATION="${OPTARG}" ;;
        w) BACKGROUND_CMD="${OPTARG}" ;;
        I) ITERATIONS="${OPTARG}" ;;
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

for i in $(seq ${ITERATIONS}); do
    "${binary}" -q -i "${INTERVAL}" -s "${STEP}" -t "${THREADS}" \
        -D "${DURATION}" --json="${LOGFILE}-${i}.json"
done

background_process_stop bgcmd

# Parse test log.
for i in $(seq ${ITERATIONS}); do
    ../../lib/parse_rt_tests_results.py cyclicdeadline "${LOGFILE}-${i}.json" \
        | tee "${TMP_RESULT_FILE}"

    if [ ${ITERATIONS} -ne 1 ]; then
        sed -i "s|^|iteration-${i}-|g" "${TMP_RESULT_FILE}"
    fi
    cat "${TMP_RESULT_FILE}" | tee -a "${RESULT_FILE}"
done

if [ "${ITERATIONS}" -gt 2 ]; then
    max_latencies_file="${OUTPUT}/max_latencies.txt"

    # Extract all max-latency values into a file
    grep "max-latency" "${RESULT_FILE}" | grep "^iteration-" | awk '{ print $(NF-1) }' |tee "${max_latencies_file}"

    if [ ! -s "${max_latencies_file}" ]; then
        echo "No max-latency values found!"
        report_fail "rt-tests-cyclicdeadline"
        exit 1
    fi

    # Find the minimum latency
    min_latency=$(sort -n "${max_latencies_file}" | head -n1)

    threshold=$(echo "$min_latency * 1.10" | bc -l)

    echo "Minimum max latency: $min_latency"
    echo "Threshold (min * 1.10): $threshold"

    # Count how many latencies exceed threshold
    fail_count=0
    while read -r val; do
        is_greater=$(echo "$val > $threshold" | bc -l)
        if [ "$is_greater" -eq 1 ]; then
            fail_count=$((fail_count + 1))
        fi
    done < "${max_latencies_file}"

    fail_limit=$((ITERATIONS / 2))

    echo "Max allowed failures: $fail_limit"
    echo "Actual failures: $fail_count"
    echo "Number of max latencies above 110% of min: $fail_count"

    if [ "$fail_count" -ge "$fail_limit" ]; then
        report_fail "rt-tests-cyclicdeadline"
    else
        report_pass "rt-tests-cyclicdeadline"
    fi
fi
