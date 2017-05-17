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
LTP_REALTIME_TESTS="async_handler gtod_latency hrtimer-prio matrix_mult measurement periodic_cpu_load pi_perf prio-preempt prio-wake pthread_kill_latency rt-migrate sched_football sched_jitter sched_latency thread_clock"

# LTP version
LTP_VERSION="20170516"
SKIP_INSTALL="false"

LTP_PATH=/opt/ltp

usage() {
    echo "Usage: ${0} [-T async_handler gtod_latency hrtimer-prio matrix_mult measurement periodic_cpu_load pi_perf prio-preempt prio-wake pthread_kill_latency rt-migrate sched_football sched_jitter sched_latency thread_clock] [-s <true|false>] [-v LTP_VERSION]" 1>&2
    exit 0
}

while getopts "T:s:v:" arg; do
   case "$arg" in
     T) LTP_REALTIME_TESTS="${OPTARG}";;
     # SKIP_INSTALL is true in case of Open Embedded builds
     # SKIP_INSTALL is false in case of Debian builds
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
}

# Run LTP realtime test suite
run_ltp_realtime() {
    # shellcheck disable=SC2164
    cd "${LTP_PATH}"
    for TEST in ${LTP_REALTIME_TESTS}; do
        pipe0_status "./testscripts/test_realtime.sh -t func/${TEST}"  "tee -a ${TMP_FILE}"
    done
    # shellcheck disable=SC2002
    cat "${TMP_FILE}" | "${SCRIPTPATH}"/ltp-realtime.py 2>&1 | tee -a "${RESULT_FILE}"
}

# Test run.
! check_root && error_msg "This script must be run as root"
create_out_dir "${OUTPUT}"

info_msg "About to run ltp realtime test..."
info_msg "Output directory: ${OUTPUT}"

if [ "${SKIP_INSTALL}" = "True" ] || [ "${SKIP_INSTALL}" = "true" ]; then
    info_msg "install_ltp skipped"
else
    dist_name
    # shellcheck disable=SC2154
    case "${dist}" in
      debian|ubuntu)
        pkgs="xz-utils flex bison build-essential wget curl net-tools"
        install_deps "${pkgs}" "${SKIP_INSTALL}"
        ;;
      centos|fedora)
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
