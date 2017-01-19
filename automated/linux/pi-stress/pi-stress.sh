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
MLOCKALL=""
RR=""

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
[ -d "${OUTPUT}" ] && mv "${OUTPUT}" "${OUTPUT}_$(date +%Y%m%d%H%M%S)"
mkdir -p "${OUTPUT}"

test "${MLOCKALL}" && MLOCKALL="--mlockall"
test "${RR}" && RR="--rr"

detect_abi
# pi_stress will send SIGTERM when test fails. The single will terminate the
# test script. Catch and ignore it with trap.
trap '' TERM
# shellcheck disable=SC2154
./bin/"${abi}"/pi_stress --duration "${DURATION}" "${MLOCKALL}" "${RR}"
check_return 'pi-stress'
