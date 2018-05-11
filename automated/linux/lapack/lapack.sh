#!/bin/sh

# shellcheck disable=SC1091
. ../../lib/sh-test-lib

OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
RESULT_LOG="${OUTPUT}/result_log.txt"
TEST_PASS_LOG="${OUTPUT}/test_pass_log.txt"
TEST_FAIL_LOG="${OUTPUT}/test_fail_log.txt"
TEST_SKIP_LOG="${OUTPUT}/test_skip_log.txt"

usage() {
    echo "Usage: $0 [-s <true|false>]" 1>&2
    exit 1
}

while getopts "s:h" o; do
  case "$o" in
    s) SKIP_INSTALL="${OPTARG}" ;;
    h|*) usage ;;
  esac
done

parse_output() {
    # Parse each type of results
    egrep "passed" "${RESULT_LOG}" | tee -a "${TEST_PASS_LOG}"
    sed -i -e 's/: /:/g' "${TEST_PASS_LOG}"
    sed -i -e 's/ \+/-/g' "${TEST_PASS_LOG}"
    sed -i -e 's/-passed:/ pass /g' "${TEST_PASS_LOG}"
    cat "${TEST_PASS_LOG}" >> "${RESULT_FILE}"

    egrep "failing" "${RESULT_LOG}" | tee -a "${TEST_FAIL_LOG}"
    sed -i -e 's/failing to pass the threshold:/FAIL:/g' "${TEST_FAIL_LOG}"
    sed -i -e 's/: /:/g' "${TEST_FAIL_LOG}"
    sed -i -e 's/ \+/-/g' "${TEST_FAIL_LOG}"
    sed -i -e 's/-FAIL:/ fail /g' "${TEST_FAIL_LOG}"
    cat "${TEST_FAIL_LOG}" >> "${RESULT_FILE}"

    egrep "Illegal Error:" "${RESULT_LOG}" | tee -a "${TEST_SKIP_LOG}"
    egrep "Info Error:" "${RESULT_LOG}" | tee -a "${TEST_SKIP_LOG}"
    sed -i -e 's/Illegal Error:/SKIP:/g' "${TEST_SKIP_LOG}"
    sed -i -e 's/Info Error:/SKIP:/g' "${TEST_SKIP_LOG}"
    sed -i -e 's/: /:/g' "${TEST_SKIP_LOG}"
    sed -i -e 's/ \+/-/g' "${TEST_SKIP_LOG}"
    sed -i -e 's/-SKIP:/ skip /g' "${TEST_SKIP_LOG}"
    cat "${TEST_SKIP_LOG}" >> "${RESULT_FILE}"

    rm -rf "${RESULT_LOG}" "${TEST_PASS_LOG}" "${TEST_FAIL_LOG}" "${TEST_SKIP_LOG}"
}

lapack_build_test() {
    git clone https://github.com/Reference-LAPACK/lapack.git
    # shellcheck disable=SC2164
    cd lapack
    cp make.inc.example make.inc
    # shellcheck disable=SC2039
    ulimit -s 100000
    make blaslib
    make | tee -a "${RESULT_LOG}"
}

install() {
    dist_name
    # shellcheck disable=SC2154
    case "${dist}" in
      debian|ubuntu)
        pkgs="binutils gcc make python sed tar wget gfortran"
        ;;
      fedora|centos)
        pkgs="binutils gcc glibc-static make python sed tar wget gcc-gfortran"
        ;;
    esac
    install_deps "${pkgs}" "${SKIP_INSTALL}"
}

# Test run.
! check_root && error_msg "This script must be run as root"
create_out_dir "${OUTPUT}"
# shellcheck disable=SC2164
cd "${OUTPUT}"

info_msg "About to run lapack test..."
info_msg "Output directory: ${OUTPUT}"

# Install packages
install

# Build lapack tests
lapack_build_test

# Parse and print lapack tests results
parse_output
