#!/bin/sh -e

TEST_DIR=$(dirname "$(realpath "$0")")
OUTPUT="${TEST_DIR}/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE
LOGFILE="${OUTPUT}/dmesg-rcutorture.txt"
TORTURE_TIME="600"

usage() {
    echo "Usage: $0 [-t <rcutorture_time>]" 1>&2
    exit 1
}

while getopts ':t:' opt; do
    case "${opt}" in
        t) TORTURE_TIME="${OPTARG}" ;;
        *) usage ;;
    esac
done

# shellcheck disable=SC1090
. "${TEST_DIR}/../../lib/sh-test-lib"

! check_root && error_msg "Please run this script as root."
create_out_dir "${OUTPUT}"

# Insert rcutoruture kernel module.
dmesg -c > /dev/null
if lsmod | grep rcutorture; then
    rmmod rcutorture || true
fi
test_cmd="modprobe rcutorture"
tc_id="modprobe-rcutorture"
skip_list="rcutorture-start rmmod-rcutorture rcutorture-end"
run_test_case "${test_cmd}" "${tc_id}" "${skip_list}"

# Check if rcutoruture started.
sleep 10
test_cmd="dmesg | grep 'rcu-torture:--- Start of test'"
tc_id="rcutorture-start"
skip_list="rmmod-rcutorture rcutorture-end"
run_test_case "${test_cmd}" "${tc_id}" "${skip_list}"
info_msg "Running rcutorture for ${TORTURE_TIME} seconds..."
sleep "${TORTURE_TIME}"

# Remove rcutoruture kernel module.
test_cmd="rmmod rcutorture"
tc_id="rmmod-rcutorture"
skip_list="rcutorture-end"
run_test_case "${test_cmd}" "${tc_id}" "${skip_list}"

# Check if rcutoruture test finished successfully.
sleep 10
dmesg > "${LOGFILE}"
if grep 'rcu-torture:--- End of test: SUCCESS' "${LOGFILE}"; then
    report_pass "rcutorture-end"
else
    report_fail "rcutorture-end"
    cat "${LOGFILE}"
fi
