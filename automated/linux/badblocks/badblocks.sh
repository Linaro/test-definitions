#!/bin/sh

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE
TEST_SUITE="badblocks"
BLOCK_DEVICE="default"

usage() {
    echo "Usage: $0 [-b <block device>] [-p <badblocks params>] [-s <skip install: true|false]" 1>&2
    exit 1
}

while getopts "b:h:p:s:" o; do
  case "$o" in
    b) BLOCK_DEVICE="${OPTARG}" ;;
    p) BADBLOCKS_PARAMS="${OPTARG}" ;;
    s) SKIP_INSTALL="${OPTARG}" ;;
    h|*) usage ;;
  esac
done

install() {
    dist_name
    # shellcheck disable=SC2154
    case "${dist}" in
      debian|ubuntu) install_deps "e2fsprogs" "${SKIP_INSTALL}";;
      unknown) warn_msg "Unsupported distro: package install skipped" ;;
    esac
}

if [ "${BLOCK_DEVICE}" = "default" ]; then
  BLOCK_DEVICE=$(mount | grep "on \/ type" | cut -d' ' -f 1)
fi

create_out_dir "${OUTPUT}"
install

command -v badblocks
exit_on_fail "badblocks-existence-check"

if [ ! -z "${BLOCK_DEVICE}" ] && [ -e "${BLOCK_DEVICE}" ]; then
  info_msg "Running ${TEST_SUITE} test on ${BLOCK_DEVICE}"
  LOG_FILE="${OUTPUT}/${TEST_SUITE}-output.txt"
  test_cmd="badblocks -v ${BADBLOCKS_PARAMS} ${BLOCK_DEVICE} 2>&1"
  pipe0_status "${test_cmd}" "tee ${LOG_FILE}"
  check_return "${TEST_SUITE}"
else
  info_msg "Skipping ${TEST_SUITE} test on ${BLOCK_DEVICE}"
  echo "${TEST_SUITE} skip" | tee -a "${RESULT_FILE}"
fi
