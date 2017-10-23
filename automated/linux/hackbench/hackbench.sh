#!/bin/sh -e

. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
ITERATION="1000"
TARGET="host"
DATASIZE="100"
LOOPS="100"
GRPS="10"
FDS="20"
PIPE="false"
THREADS="false"

usage() {
    echo "Usage: $0 [-i <iterations>] [-t <host|kvm>] [-s <bytes>] [-l <loops>]
        [-g <groups>] [-f <fds>] [-p <true|false>] [-T <true|false>] [-h]" 1>&2
    exit 1
}

while getopts "i:t:s:l:g:f:p:T:h" o; do
    case "$o" in
        i) ITERATION="${OPTARG}" ;;
        t) TARGET="${OPTARG}" ;;
        s) DATASIZE="${OPTARG}" ;;
        l) LOOPS="${OPTARG}" ;;
        g) GRPS="${OPTARG}" ;;
        f) FDS="${OPTARG}" ;;
        p) PIPE="${OPTARG}" ;;
        T) THREADS="${OPTARG}" ;;
        h|*) usage ;;
    esac
done

create_out_dir "${OUTPUT}"
TEST_LOG="${OUTPUT}/hackbench-output-${TARGET}.txt"

# Determine hackbench test options.
OPTS="-s ${DATASIZE} -l ${LOOPS} -g ${GRPS} -f ${FDS}"
if "${PIPE}"; then
    OPTS="${OPTS} -p"
fi
if "${THREADS}"; then
    OPTS="${OPTS} -T"
fi
info_msg "Hackbench test options: ${OPTS}"

# Test run.
if ! binary=$(which hackbench); then
    detect_abi
    # shellcheck disable=SC2154
    binary="./bin/${abi}/hackbench"
fi
for i in $(seq "${ITERATION}"); do
    info_msg "Running iteration [$i/${ITERATION}]"
    "${binary}" "${OPTS}" 2>&1 | tee -a "${TEST_LOG}"
done

# Parse output.
grep "^Time" "${TEST_LOG}" \
    | awk '{
               if(min=="") {min=max=$2};
               if($2>max) {max=$2};
               if($2< min) {min=$2};
               total+=$2; count+=1;
           }
       END {
               printf("hackbench-mean pass %s s\n", total/count);
               printf("hackbench-min pass %s s\n", min);
               printf("hackbench-max pass %s s\n", max)
           }' \
    | tee -a "${RESULT_FILE}"
