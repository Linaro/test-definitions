#!/bin/sh

. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
mkdir -p "${OUTPUT}"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE

usage() {
    echo "Usage: $0 [-s <true|false>]" 1>&2
    exit 1
}

while getopts "s:" o; do
  case "$o" in
    s) SKIP_INSTALL="${OPTARG}" ;;
    *) usage ;;
  esac
done

install() {
    dist_name
    case "${dist}" in
      Debian|Ubuntu) pkgs="lsb-release" ;;
      Fedora|CentOS) pkgs="redhat-lsb-core" ;;
    esac

    install_deps "${pkgs}" "${SKIP_INSTALL}"
}

run() {
    local test="$1"
    test_case_id="$(echo "${test}" | awk '{print $1}')"
    echo
    info_msg "Running ${test_case_id} test..."
    eval "${test}"
    check_return "${test_case_id}"
}

# Test run.
[ -f "${OUTPUT}" ] && \
mv "${OUTPUT}" "${OUTPUT}_$(date +%Y%m%d%H%M%S)"

install
run "pwd"
run "lsb_release -a"
run "uname -a"
run "ip a"
run "lscpu"
run "vmstat"
run "lsblk"
