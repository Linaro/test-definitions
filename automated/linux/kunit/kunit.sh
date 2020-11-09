#!/bin/sh

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE
TEST_LOG="${OUTPUT}/test_log.txt"
TEST_PASS_FAIL_LOG="${OUTPUT}/test_pass_fail_log.txt"
TEST_CMD="dmesg"
TEST_CMD_FILE="${OUTPUT}/${TEST_CMD}.txt"
# Example KUNIT_TEST_MODULE="kunit-test.ko"
KUNIT_TEST_MODULE=""

usage() {
    echo "Usage: $0 [-m <kunit test module> ]" 1>&2
    exit 1
}

while getopts "m:h" o; do
  case "$o" in
    m) KUNIT_TEST_MODULE="${OPTARG}" ;;
    h|*) usage ;;
  esac
done

run() {
    test="$1"
    "${test}" > "${TEST_CMD_FILE}"
    check_return "${test}"
}

# Example Test output to be parsed
# [    2.561241]     ok 4 - mptcp_token_test_destroyed
# [    2.562914] ok 12 - mptcp-token
# [    2.562984] not ok 1 test_xdp_veth.sh_1 # SKIP
# [    2.564424] not ok 2 test_xdp_veth.sh_2

parse_results() {
    test_log_file="$1"
    grep -e "not ok" -e "ok" "${test_log_file}" > "${TEST_LOG}"
    while read -r line; do {
	# shellcheck disable=SC2046
        if [ $(echo "${line}" | awk '{print $NF }') = "SKIP" ]; then
	    echo "${line}" | awk '{print $(NF-2) " " "skip"}' 2>&1 | tee -a "${RESULT_FILE}"
        else
            echo "${line}" 2>&1 | tee -a "${TEST_PASS_FAIL_LOG}"
        fi
    } done < "${TEST_LOG}"

    sed  -i -e 's/not ok/fail/g' "${TEST_PASS_FAIL_LOG}"
    sed  -i -e 's/ok/pass/g' "${TEST_PASS_FAIL_LOG}"
    awk '{print $NF " " $3}' "${TEST_PASS_FAIL_LOG}"  2>&1 | tee -a "${RESULT_FILE}"
}

check_root || error_msg "Please run this script as root"
# Test run.
create_out_dir "${OUTPUT}"

if [ -n "${KUNIT_TEST_MODULE}" ] && ! lsmod | grep "${KUNIT_TEST_MODULE%.*}";
then
    echo KUNIT_TEST_MODULE="${KUNIT_TEST_MODULE}"
    ln -s "$(find "/lib/modules/$(uname -r)" -name "${KUNIT_TEST_MODULE}*")" \
        "/lib/modules/$(uname -r)"
    depmod -a
    modprobe "${KUNIT_TEST_MODULE%.*}"
    exit_on_fail "modprobe-${KUNIT_TEST_MODULE%.*}"
    lsmod
else
    if [ -f /proc/config.gz ]
    then
        CONFIG_KUNIT_TEST=$(zcat /proc/config.gz | grep "CONFIG_KUNIT_TEST=")
    elif [ -f /boot/config-"$(uname -r)" ]
    then
        KERNEL_CONFIG_FILE="/boot/config-$(uname -r)"
        CONFIG_KUNIT_TEST=$(grep "CONFIG_KUNIT_TEST=" "${KERNEL_CONFIG_FILE}")
    else
        exit_on_skip "kunit-pre-requirements" "Kernel config file not available"
    fi
    if [ "${CONFIG_KUNIT_TEST}" = "CONFIG_KUNIT_TEST=y" ]
    then
        exit_on_skip "kunit-pre-requirements" "Kernel config CONFIG_KUNIT_TEST=y not enabled"
    fi
fi

run "${TEST_CMD}"
parse_results "${TEST_CMD_FILE}"
