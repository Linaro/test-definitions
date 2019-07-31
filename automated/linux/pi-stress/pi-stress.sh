#!/bin/sh
# pi_stress checks Priority Inheritence Mutexes and their ability to avoid
# Priority Inversion from occuring by running groups of threads that cause
# Priority Inversions.

# shellcheck disable=SC1091
. ../../lib/sh-test-lib

OUTPUT="$(pwd)/output"
LOGFILE="${OUTPUT}/pi-stress.txt"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE

DURATION="5m"
MLOCKALL="false"
RR="false"
BACKGROUND_CMD=""

usage() {
    echo "Usage: $0 [-D runtime] [-m <true|false>] [-r <true|false>] [-w background_cmd]" 1>&2
    exit 1
}

while getopts ":D:m:r:w" opt; do
    case "${opt}" in
        D) DURATION="${OPTARG}" ;;
        m) MLOCKALL="${OPTARG}" ;;
        r) RR="${OPTARG}" ;;
	w) BACKGROUND_CMD="${OPTARG}" ;;
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

# pi_stress will send SIGTERM when test fails. The single will terminate the
# test script. Catch and ignore it with trap.
trap '' TERM
"${binary}" --duration "${DURATION}" "${MLOCKALL}" "${RR}" | tee "${LOGFILE}"

background_process_stop bgcmd

# shellcheck disable=SC2181
if [ "$?" -ne "0" ]; then
    report_fail "pi-stress"
elif grep -q -e "^ERROR:" -e "is deadlocked!" "${LOGFILE}"; then
    report_fail "pi-stress"
elif ! grep -q -e "Current Inversions:" "${LOGFILE}"; then
    report_fail "pi-stress"
else
    report_pass "pi-stress"
fi
