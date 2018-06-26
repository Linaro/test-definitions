#!/bin/bash

set -x

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
# Absolute path to this script. /home/user/bin/foo.sh
SCRIPT="$(readlink -f "${0}")"
# Absolute path this script is in. /home/user/bin
SCRIPTPATH="$(dirname "${SCRIPT}")"
echo "Script path is: ${SCRIPTPATH}"
SKIP_INSTALL="true"
# List of test cases
TEST="conformance functional stress"
# LTP version
LTP_VERSION="20180515"

LTP_PRE_INSTALL=/opt/ltp
LTP_PATH=/opt/ltp/testcases/open_posix_testsuite

while getopts "s:v:" arg; do
   case "$arg" in
     s) SKIP_INSTALL="${OPTARG}";;
     v) LTP_VERSION="${OPTARG}";;
   esac
done

# Install LTP open posix test suite
install_ltp_open_posix() {
    rm -rf "${LTP_PRE_INSTALL}"
    mkdir -p "${LTP_PRE_INSTALL}"
    # shellcheck disable=SC2164
    cd "${LTP_PRE_INSTALL}"
    # shellcheck disable=SC2140
    wget https://github.com/linux-test-project/ltp/releases/download/"${LTP_VERSION}"/ltp-full-"${LTP_VERSION}".tar.xz
    tar --strip-components=1 -Jxf ltp-full-"${LTP_VERSION}".tar.xz
    ./configure --with-open-posix-testsuite
    # shellcheck disable=SC2164
    cd "${LTP_PATH}"
    make generate-makefiles || true

    for EACH_TEST in ${TEST}
    do
      make "${EACH_TEST}"-all || true
    done
}

# Parse LTP open posix output
parse_ltp_output() {
    for EACH_TEST in ${TEST}
    do
      sed -i -e "s/\// /g" logfile."${EACH_TEST}"-test
      grep -E ": PASS"  logfile."${EACH_TEST}"-test \
         | awk '{print $(NF-2)" "$(NF)}' \
         | sed 's/://g; s/PASS/pass/'  >> "${RESULT_FILE}"
      grep -E ": FAILED|: SKIPPED|: UNSUPPORTED|: UNTESTED|: UNRESOLVED|: HUNG"  logfile."${EACH_TEST}"-test \
         | awk '{print $(NF-3)" "$(NF-1)}' \
         | sed 's/://g; s/FAILED/fail/; s/SKIPPED/skip/; s/UNSUPPORTED/skip/; s/UNTESTED/skip/; s/UNRESOLVED/skip/; s/HUNG/skip/'  >> "${RESULT_FILE}"
    done

}

# Run LTP test suite
run_ltp_open_posix() {
    # shellcheck disable=SC2164
    cd "${LTP_PATH}"
    for EACH_TEST in ${TEST}
    do
      make "${EACH_TEST}"-test || true
    done
    parse_ltp_output
}

# Test run.
! check_root && error_msg "This script must be run as root"
create_out_dir "${OUTPUT}"

info_msg "About to run ltp test..."
info_msg "Output directory: ${OUTPUT}"

if [ "${SKIP_INSTALL}" = "True" ] || [ "${SKIP_INSTALL}" = "true" ]; then
    info_msg "install-ltp-open-posix skipped"
else
    dist_name
    # shellcheck disable=SC2154
    case "${dist}" in
      debian|ubuntu)
        pkgs="xz-utils flex bison build-essential wget curl net-tools sudo libaio-dev expect automake acl"
        install_deps "${pkgs}" "${SKIP_INSTALL}"
        ;;
      centos|fedora)
        pkgs="xz flex bison make automake gcc gcc-c++ kernel-devel wget curl net-tools sudo libaio expect acl"
        install_deps "${pkgs}" "${SKIP_INSTALL}"
        ;;
      *)
        warn_msg "Unsupported distribution: package install skipped"
    esac

    info_msg "Run install-ltp-open-posix"
    install_ltp_open_posix
fi
info_msg "Running run-ltp-open-posix"
run_ltp_open_posix
