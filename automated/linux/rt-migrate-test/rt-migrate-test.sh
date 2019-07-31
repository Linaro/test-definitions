#!/bin/sh -e
# rt-migrate-test verifies the RT threads scheduler balancing.

# shellcheck disable=SC1091
. ../../lib/sh-test-lib

OUTPUT="$(pwd)/output"
LOGFILE="${OUTPUT}/rt-migrate-test.txt"
RESULT_FILE="${OUTPUT}/result.txt"
PRIORITY="96"
DURATION="1m"
BACKGROUND_CMD=""

usage() {
    echo "Usage: $0 [-p priority] [-D duration] [-w background_cmd]" 1>&2
    exit 1
}

while getopts ":l:p:D:w:" opt; do
    case "${opt}" in
	p) PRIORITY="${OPTARG}" ;;
	D) DURATION="${OPTARG}" ;;
	w) BACKGROUND_CMD="${OPTARG}" ;;
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

"${binary}" -p "${PRIORITY}" -D "${DURATION}" -c | tee "${LOGFILE}"

background_process_stop bgcmd

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
