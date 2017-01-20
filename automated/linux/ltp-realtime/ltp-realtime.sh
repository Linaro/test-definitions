#!/bin/bash

. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
TMP_FILE="${OUTPUT}/tmp.txt"

# Absolute path to this script. /home/user/bin/foo.sh
SCRIPT="$(readlink -f "${0}")"
# Absolute path this script is in. /home/user/bin
SCRIPTPATH="$(dirname "${SCRIPT}")"
echo "Script path is: ${SCRIPTPATH}"
# List of test cases
LTP_REALTIME_TESTS="thread_clock"
# LTP version
LTP_VERSION="20170116"
SKIP_INSTALL="false"

LTP_PATH=/opt/ltp

usage() {
    echo "Usage: ${0} [-T async_handler] [-s <flase>] [-v LTP_VERSION]" 1>&2
    exit 0
}

while getopts "T:s:v:" arg; do
   case "$arg" in
     T) LTP_REALTIME_TESTS="${OPTARG}";;
     # SKIP_INSTALL is true in case of Open Embedded builds
     # SKIP_INSTALL is flase in case of Debian builds
     s) SKIP_INSTALL="${OPTARG}";;
     v) LTP_VERSION="${OPTARG}";;
  esac
done

# Install LTP test suite
install_ltp() {
    rm -rf /opt/ltp
    mkdir -p /opt/ltp
    # shellcheck disable=SC2164
    cd /opt/ltp
    # shellcheck disable=SC2140
    wget https://github.com/linux-test-project/ltp/releases/download/"${LTP_VERSION}"/ltp-full-"${LTP_VERSION}".tar.xz
    tar --strip-components=1 -Jxf ltp-full-"${LTP_VERSION}".tar.xz
    ./configure --with-realtime-testsuite
    make -C testcases/realtime/
    make SKIP_IDCHECK=1 install
}

# Run LTP test suite
run_ltp_realtime() {
    # shellcheck disable=SC2164
    cd "${LTP_PATH}"
    for TEST in ${LTP_REALTIME_TESTS}; do
	pipe0_status "./testscripts/test_realtime.sh -t func/${TEST}"  "tee -a ${TMP_FILE}"
        check_return "${TEST}"
    done
    cat "${TMP_FILE}" | "${SCRIPTPATH}"/ltp-realtime.py 2>&1 | tee -a "${RESULT_FILE}"
}

# Test run.
! check_root && error_msg "This script must be run as root"
[ -d "${OUTPUT}" ] && mv "${OUTPUT}" "${OUTPUT}_$(date +%Y%m%d%H%M%S)"
mkdir -p "${OUTPUT}"

info_msg "About to run ltp realtime test..."
info_msg "Output directory: ${OUTPUT}"

if [ "${SKIP_INSTALL}" = "True" ] || [ "${SKIP_INSTALL}" = "true" ]; then
    info_msg "install_ltp skipped"
else
    dist_name
    # shellcheck disable=SC2154
    case "${dist}" in
      Debian|Ubuntu)
        pkgs="xz-utils flex bison build-essential wget curl net-tools"
        install_deps "${pkgs}" "${SKIP_INSTALL}"
        ;;
      CentOS|Fedora)
        pkgs="xz flex bison make automake gcc gcc-c++ kernel-devel wget curl net-tools"
        install_deps "${pkgs}" "${SKIP_INSTALL}"
        ;;
      *)
        warn_msg "Unsupported distribution: package install skipped"
    esac
    info_msg "Run install_ltp"
    install_ltp
fi
info_msg "Running run_ltp_realtime"
run_ltp_realtime
