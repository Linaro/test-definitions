#!/bin/sh

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
RESULT_LOG="${OUTPUT}/result_log.txt"
TEST_LOG="${OUTPUT}/test_log.txt"

usage() {
    echo "Usage: $0 [-s <true|false>]" 1>&2
    exit 1
}

parse_output() {
    egrep "^failed|^ok" "${TEST_LOG}"  2>&1 | tee -a "${RESULT_LOG}"
    sed -i -e 's/ok/pass/g' "${RESULT_LOG}"
    sed -i -e 's/failed/fail/g' "${RESULT_LOG}"
    awk '{for (i=2; i<NF; i++) printf $i "-"; print $NF " " $1}' "${RESULT_LOG}" 2>&1 | tee -a "${RESULT_FILE}"
}

while getopts "s:" o; do
  case "$o" in
    s) SKIP_INSTALL="${OPTARG}" ;;
    *) usage ;;
  esac
done

# Test run.
! check_root && error_msg "This script must be run as root"
create_out_dir "${OUTPUT}"

pkgs="build-essential"
install_deps "${pkgs}" "${SKIP_INSTALL}"


info_msg "About to run openssh test..."
info_msg "Output directory: ${OUTPUT}"

apt-get update
apt-get source openssh
VERSION=$(dpkg -l | grep openssh-client |awk '{print $3}'|cut -d- -f 1 | cut -d: -f2)
# shellcheck disable=SC2164
cd openssh-"${VERSION}"
./configure
make
make install
make tests  2>&1 | tee -a "${TEST_LOG}"

parse_output
