#!/bin/sh
# rt-migrate-test verifies the RT threads scheduler balancing.

# shellcheck disable=SC1091
. ../../lib/sh-test-lib

OUTPUT="$(pwd)/output"
LOGFILE="${OUTPUT}/rt-migrate-test"
RESULT_FILE="${OUTPUT}/result.txt"
TMP_RESULT_FILE="${OUTPUT}/tmp_result.txt"

PRIORITY="51"
DURATION="1m"
BACKGROUND_CMD=""
ITERATIONS=1

usage() {
    echo "Usage: $0 [-p priority] [-D duration] [-w background_cmd] [-i iterations]" 1>&2
    exit 1
}

while getopts ":l:p:D:w:i:" opt; do
    case "${opt}" in
        p) PRIORITY="${OPTARG}" ;;
        D) DURATION="${OPTARG}" ;;
        w) BACKGROUND_CMD="${OPTARG}" ;;
        i) ITERATIONS="${OPTARG}" ;;
        *) usage ;;
    esac
done

! check_root && error_msg "Please run this script as root."
create_out_dir "${OUTPUT}"

# Run rt-migrate-test.
if ! binary=$(command -v rt-migrate-test); then
    detect_abi
    # shellcheck disable=SC2154
    binary="./bin/${abi}/rt-migrate-test"
fi

background_process_start bgcmd --cmd "${BACKGROUND_CMD}"

for i in $(seq ${ITERATIONS}); do
    "${binary}" -q -p "${PRIORITY}" -D "${DURATION}" -c --json="${LOGFILE}-${i}.json"
done


background_process_stop bgcmd

# Parse test log.
for i in $(seq ${ITERATIONS}); do
    ../../lib/parse_rt_tests_results.py rt-migrate-test "${LOGFILE}-${i}.json" \
        | tee "${TMP_RESULT_FILE}"

    if [ ${ITERATIONS} -ne 1 ]; then
        sed -i "s|^|iteration-${i}-|g" "${TMP_RESULT_FILE}"
    fi
    cat "${TMP_RESULT_FILE}" | tee -a "${RESULT_FILE}"
done
