#!/bin/sh

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE
TESTS="pwd lsb_release uname ip lscpu vmstat lsblk"

usage() {
    echo "Usage: $0 [-s <true|false>] [-t TESTS]" 1>&2
    exit 1
}

while getopts "s:t:h" o; do
  case "$o" in
    s) SKIP_INSTALL="${OPTARG}" ;;
    t) TESTS="${OPTARG}" ;;
    h|*) usage ;;
  esac
done

install() {
    dist_name
    # shellcheck disable=SC2154
    case "${dist}" in
      debian|ubuntu) install_deps "lsb-release" "${SKIP_INSTALL}";;
      fedora|centos) install_deps "redhat-lsb-core" "${SKIP_INSTALL}";;
      unknown) warn_msg "Unsupported distro: package install skipped" ;;
    esac
}

run() {
    # shellcheck disable=SC2039
    local test="$1"
    test_case_id="$(echo "${test}" | awk '{print $1}')"
    echo
    info_msg "Running ${test_case_id} test..."
    eval "${test}"
    check_return "${test_case_id}"
}

# Test run.
create_out_dir "${OUTPUT}"

install
string_contains 'pwd' "$TESTS" && run "pwd"
string_contains 'lsb_release' "$TESTS" && run "lsb_release -a"
string_contains 'uname' "$TESTS" && run "uname -a"
string_contains 'ip' "$TESTS" && run "ip a"
string_contains 'lscpu' "$TESTS" && run "lscpu"
string_contains 'vmstat' "$TESTS" && run "vmstat"
string_contains 'lsblk' "$TESTS" && run "lsblk"
