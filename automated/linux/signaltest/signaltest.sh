#!/bin/sh
# signaltest is a RT signal roundtrip test software.

# shellcheck disable=SC1091
. ../../lib/sh-test-lib

OUTPUT="$(pwd)/output"
LOGFILE="${OUTPUT}/signaltest.json"
RESULT_FILE="${OUTPUT}/result.txt"

PRIORITY="98"
THREADS="2"
DURATION="1m"
BACKGROUND_CMD=""

usage() {
    echo "Usage: $0 [-r runtime] [-p priority] [-t threads] [-w background_cmd]" 1>&2
    exit 1
}

while getopts ":p:t:D:w:" opt; do
    case "${opt}" in
        p) PRIORITY="${OPTARG}" ;;
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

# Run signaltest.
if ! binary=$(command -v signaltest); then
    detect_abi
    # shellcheck disable=SC2154
    binary="./bin/${abi}/signaltest"
fi

background_process_start bgcmd --cmd "${BACKGROUND_CMD}"

"${binary}" -q -D "${DURATION}" -a -m -p "${PRIORITY}" -t "${THREADS}" --json="${LOGFILE}"

background_process_stop bgcmd

# Parse test log.
../../lib/parse_rt_tests_results.py signaltest "${LOGFILE}" \
    | tee -a "${RESULT_FILE}"
