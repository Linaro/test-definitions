#!/bin/sh -e
# rt-migrate-test verifies the RT threads scheduler balancing.

# shellcheck disable=SC1091
. ../../lib/sh-test-lib

OUTPUT="$(pwd)/output"
LOGFILE="${OUTPUT}/rt-migrate-test.txt"
RESULT_FILE="${OUTPUT}/result.txt"
DURATION="1m"

usage() {
    echo "Usage: $0 [-D duration]" 1>&2
    exit 1
}

while getopts ":l:D:" opt; do
    case "${opt}" in
	D) DURATION="${OPTARG}" ;;
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
"${binary}" -D "${DURATION}" -c | tee "${LOGFILE}"

# Parse test log.
task_num=$(grep "Task" "${LOGFILE}" | tail -1 | awk '{print $2}')
r=$(sed -n 's/Passed!/pass/p; s/Failed!/fail/p' "${LOGFILE}")
for t in $(seq 0 "${task_num}"); do
    # Get the priority of the task.
    p=$(grep "Task $t" "${LOGFILE}" | awk '{print substr($4,1,length($4)-1)}')
    sed -n "/Task $t/,/Avg/p" "${LOGFILE}" \
        | grep -v "Task" \
        | awk -v t="$t" -v p="$p" -v r="$r" '{printf("t%s-p%s-%s %s %s %s\n",t,p,tolower(substr($1, 1, length($1)-1)),r,$2,$3)}' \
        | tee -a "${RESULT_FILE}"
done
