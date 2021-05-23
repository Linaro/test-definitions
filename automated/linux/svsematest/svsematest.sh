#!/bin/sh -e
# shellcheck disable=SC1090
# shellcheck disable=SC2154
# svsematest starts two threads or, optionally, forks two processes that
# are synchronized via SYSV semaphores and measures the latency between
# releasing a semaphore on one side and getting it on the other side.

TEST_DIR=$(dirname "$(realpath "$0")")
OUTPUT="${TEST_DIR}/output"
LOGFILE="${OUTPUT}/svsematest.log"
RESULT_FILE="${OUTPUT}/result.txt"
DURATION="5m"
BACKGROUND_CMD=""

usage() {
    echo "Usage: $0 [-D duration] [-w background_cmd]" 1>&2
    exit 1
}

while getopts ":D:w:" opt; do
    case "${opt}" in
        D) DURATION="${OPTARG}" ;;
	w) BACKGROUND_CMD="${OPTARG}" ;;
        *) usage ;;
    esac
done

. "${TEST_DIR}/../../lib/sh-test-lib"

! check_root && error_msg "Please run this script as root."
create_out_dir "${OUTPUT}"

# Run svsematest.
if ! binary=$(command -v svsematest); then
    detect_abi
    # shellcheck disable=SC2154
    binary="./bin/${abi}/svsematest"
fi

background_process_start bgcmd --cmd "${BACKGROUND_CMD}"

"${binary}" -q -t -a -p 98 -D "${DURATION}" | tee "${LOGFILE}"

background_process_stop bgcmd

# Parse test log.
../../lib/parse_rt_tests_results.py svsematest "${LOGFILE}" \
    | tee -a "${RESULT_FILE}"
