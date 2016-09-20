#!/bin/bash

. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
# Absolute path to this script. /home/user/bin/foo.sh
SCRIPT="$(readlink -f $0)"
# Absolute path this script is in. /home/user/bin
SCRIPTPATH="$(dirname $SCRIPT)"
echo "Script path is: "${SCRIPTPATH}""
# List of test cases
TST_CMDFILES=""
# List of test cases to be skipped
SKIPFILE=""

LTP_PATH=/opt/ltp

usage() {
    echo "Usage: $0 [-T mm,math,syscalls] [-S skipfile-lsk-juno] [-s <flase>]" 1>&2
    exit 0
}
while getopts "T:S:s:" arg; do
   case "$arg" in
     T) TST_CMDFILES="${OPTARG}"
        LOG_FILE=$(echo "${OPTARG}"| sed 's,\/,_,');;
     S) OPT=$(echo "${OPTARG}" | grep "http")
        if [ -z "${OPT}" ] ; then
        # LTP skipfile
          SKIPFILE="-S "${SCRIPTPATH}"/"${OPTARG}""
        else
        # Download LTP skipfile from speficied URL
          wget "${OPTARG}"
          SKIPFILE=$(echo "${OPTARG##*/}")
          SKIPFILE="-S $(pwd)/"${SKIPFILE}""
        fi
        ;;
     # SKIP_INSTALL is true in case of OE builds
     # SKIP_INSTALL is flase in case of Debian builds
     s) SKIP_INSTALL="${OPTARG}";;
  esac
done

# Install LTP test suite
install_ltp() {
    VERSION=20160510
    rm -rf /opt/ltp
    mkdir -p /opt/ltp
    cd /opt/ltp
    wget https://github.com/linux-test-project/ltp/releases/download/"${VERSION}"/ltp-full-"${VERSION}".tar.xz
    tar --strip-components=1 -Jxf ltp-full-"${VERSION}".tar.xz
    ./configure
    make -j8 all
    make SKIP_IDCHECK=1 install
}

# Parse LTP output
parse_ltp_output() {
    egrep "PASS|FAIL|CONF"  "$1" | awk '{print $1" "$2}' | sed s/CONF/SKIP/  > "${RESULT_FILE}"
}

# Run LTP test suite
run_ltp() {
    cd "${LTP_PATH}"
    RESULT=pass

    exec 4>&1
    error_statuses="$(((./runltp -p -q -f "${TST_CMDFILES}" \
        -l "${SCRIPTPATH}"/LTP_"${LOG_FILE}".log \
        -C "$SCRIPTPATH"/LTP_"${LOG_FILE}".failed "${SKIPFILE}" \
        ||  echo "0:$?" >&3) | (tee "${SCRIPTPATH}"/LTP_"${LOG_FILE}".out \
        ||  echo "1:$?" >&3)) 3>&1 >&4)"
    exec 4>&-

    ! echo "${error_statuses}" | grep '0:' >/dev/null
    if [ $? -ne 0 ]; then
        RESULT=fail
    fi
    parse_ltp_output "${SCRIPTPATH}"/LTP_"${LOG_FILE}".log
}

# Test run.
! check_root && error_msg "This script must be run as root"
[ -d "${OUTPUT}" ] && mv "${OUTPUT}" "${OUTPUT}_$(date +%Y%m%d%H%M%S)"
mkdir -p "${OUTPUT}"

info_msg "About to run ltp test..."
info_msg "Output directory: ${OUTPUT}"

if [ "${SKIP_INSTALL}" = "True" ] || [ "${SKIP_INSTALL}" = "true" ]; then
    info_msg "install_ltp skipped"
    info_msg "Running run_ltp"
    run_ltp
else
    pkgs="xz-utils flex bison build-essential wget curl"
    install_deps "${pkgs}" "${SKIP_INSTALL}"
    info_msg "Run install_ltp"
    install_ltp
    info_msg "Running run_ltp"
    run_ltp
fi
