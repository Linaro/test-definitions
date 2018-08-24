#!/bin/sh -ex

TEST_DIR=$(dirname "$(realpath "$0")")
OUTPUT="${TEST_DIR}/output"
LOGFILE="${OUTPUT}/stdout.txt"
RESULT_FILE="${OUTPUT}/result.txt"

TEST="automated/linux/smoke/smoke.yaml"
TESTDEF_PARAMS=""
DOCKER_IMG="linaro/testdef-arm64-debian-stretch:922033e"

usage() {
    echo "Usage: $0 [-t <test>] [-r <testdef_params>] [-d <docker_img>]" 1>&2
    exit 1
}

while getopts "t:r:d:h" opt; do
    case "$opt" in
        t) TEST="${OPTARG}" ;;
        r) TESTDEF_PARAMS="${OPTARG}" ;;
        d) DOCKER_IMG="${OPTARG}" ;;
        *) usage ;;
    esac
done

# SC1090: Can't follow non-constant source. Use a directive to specify location.
# shellcheck disable=SC1090
. "${TEST_DIR}/../../lib/sh-test-lib"
create_out_dir "${OUTPUT}"

# Assume docker pre-installed on test target.
command -v docker || error_msg "docker not found on test target!"

# Trigger test run.
cmd1="docker run --privileged --init ${DOCKER_IMG} test-runner -d ${TEST}"
[ -n "${TESTDEF_PARAMS}" ] && cmd1="${cmd1} -r ${TESTDEF_PARAMS}"
if ! pipe0_status "${cmd1}" "tee -a ${LOGFILE}"; then
    echo "docker-run fail" | tee -a "${RESULT_FILE}"
    info_msg "Usage: check automated/linux/dockerized-tests/README.md"
    error_msg "Test run with docker failed!"
fi

# Parse test log.
awk '/^<TEST_CASE_ID/ {gsub(/(<|>|=|TEST_CASE_ID|RESULT|UNITS|MEASUREMENT)/,""); print}' "${LOGFILE}" \
    | tee -a "${RESULT_FILE}"
