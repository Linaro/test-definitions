#!/bin/sh -e
# rt-migrate-test verifies the RT threads scheduler balancing.

# shellcheck disable=SC1091
. ../../lib/sh-test-lib

OUTPUT="$(pwd)/output"
LOGFILE="${OUTPUT}/rt-migrate-test.txt"
RESULT_FILE="${OUTPUT}/result.txt"
LOOPS="100"

usage() {
    echo "Usage: $0 [-l loops]" 1>&2
    exit 1
}

while getopts ":l:" opt; do
    case "${opt}" in
        l) LOOPS="${OPTARG}" ;;
        *) usage ;;
    esac
done

! check_root && error_msg "Please run this script as root."
create_out_dir "${OUTPUT}"

# Run rt-migrate-test.
if ! binary=$(which rt-migrate-test); then
    detect_abi
    # shellcheck disable=SC2154
    binary="./bin/${abi}/rt-migrate-test"
fi
"${binary}" -l "${LOOPS}" | tee "${LOGFILE}"

# Parse test log.
task_num=$(grep "Task" "${LOGFILE}" | tail -1 | awk '{print $2}')
for t in $(seq 0 "${task_num}"); do
    # Get the priority of the task.
    p=$(grep "Task $t" "${LOGFILE}" | awk '{print substr($4,1,length($4)-1)}')
    sed -n "/Task $t/,/Avg/p" "${LOGFILE}" \
        | grep -v "Task" \
        | awk -v t="$t" -v p="$p" '{printf("t%s-p%s-%s pass %s %s\n",t,p,tolower(substr($1, 1, length($1)-1)),$2,$3)}' \
        | tee -a "${RESULT_FILE}"
done
