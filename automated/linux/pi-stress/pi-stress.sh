#!/bin/sh
# pi_stress checks Priority Inheritence Mutexes and their ability to avoid
# Priority Inversion from occuring by running groups of threads that cause
# Priority Inversions.

# shellcheck disable=SC1091
. ../../lib/sh-test-lib

OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE

DURATION="300"
MLOCKALL="false"
RR="false"

usage() {
    echo "Usage: $0 [-d duration] [-m <true|false>] [-r <true|false>]" 1>&2
    exit 1
}

while getopts ":d:m:r:" opt; do
    case "${opt}" in
        d) DURATION="${OPTARG}" ;;
        m) MLOCKALL="${OPTARG}" ;;
        r) RR="${OPTARG}" ;;
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

if ! binary=$(which pi_stress); then
    detect_abi
    # shellcheck disable=SC2154
    binary="./bin/${abi}/pi_stress"
fi
# pi_stress will send SIGTERM when test fails. The single will terminate the
# test script. Catch and ignore it with trap.
trap '' TERM
"${binary}" --duration "${DURATION}" "${MLOCKALL}" "${RR}"
check_return 'pi-stress'
