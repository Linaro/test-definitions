#!/bin/bash

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"

RESULT_LOG="${OUTPUT}/result_log.txt"
TMP_LOG="${OUTPUT}/tmp_log.txt"

TEST_PROGRAM=packetdrill
TEST_PROG_VERSION=
TEST_GIT_URL=https://github.com/google/packetdrill.git
TEST_DIR="$(pwd)/${TEST_PROGRAM}"
INSTALL_PATH="/opt/${TEST_PROGRAM}"
SKIP_INSTALL="false"

usage() {
    echo "\
    Usage: [sudo] ./packetdrill.sh [-d <INSTALL_PATH>] [-v <TEST_PROG_VERSION>]
                  [-u <TEST_GIT_URL>] [-p <TEST_DIR>] [-s <true|false>]

    <TEST_PROG_VERSION>:
    If this parameter is set, then the ${TEST_PROGRAM} is cloned. In
    particular, the version of the suite is set to the commit
    pointed to by the parameter. A simple choice for the value of
    the parameter is, e.g., HEAD. If, instead, the parameter is
    not set, then the suite present in TEST_DIR is used.

    <TEST_GIT_URL>:
    If this parameter is set, then the ${TEST_PROGRAM} is cloned
    from the URL in TEST_GIT_URL. Otherwise it is cloned from the
    standard repository for the suite. Note that cloning is done
    only if TEST_PROG_VERSION is not empty

    <TEST_DIR>:
    If this parameter is set, then the ${TEST_PROGRAM} suite is cloned to or
    looked for in TEST_DIR. Otherwise it is cloned to /opt/${TEST_PROGRAM}

    <INSTALL_PATH>:
    # If next parameter is set, then the packetdrill suite installed in this PATH

    <SKIP_INSTALL>:
    If you already have it installed into the rootfs.
    default: false"
}

while getopts "d:h:p:s:u:v:" opt; do
    case $opt in
        d)
            if [[ "$OPTARG" != '' ]]; then
                INSTALL_PATH="${OPTARG}"
            fi
            ;;
        p)
            if [[ "$OPTARG" != '' ]]; then
                TEST_DIR="${OPTARG}"
            fi
            ;;
        s)
            SKIP_INSTALL="${OPTARG}"
            ;;
        u)
            if [[ "$OPTARG" != '' ]]; then
                TEST_GIT_URL="${OPTARG}"
            fi
            ;;
        v)
            TEST_PROG_VERSION="${OPTARG}"
            ;;
        h)
            usage
            exit 0
            ;;
        *)
            usage
            exit 1
            ;;
    esac
done

install() {
    dist=
    dist_name
    case "${dist}" in
        debian|ubuntu)
          [[ -n "${TEST_GIT_URL}" ]] && pkgs="git"
          pkgs="${pkgs} build-essential automake curl bison flex ethtool net-tools iproute2 python python3"
          install_deps "${pkgs}" "${SKIP_INSTALL}"
          ;;
        fedora|centos)
          [[ -n "${TEST_GIT_URL}" ]] && pkgs="git-core"
          pkgs=" ${pkgs} gcc gcc-c++ kernel-devel make automake curl bison flex ethtool net-tools iproute2 python python3"
          install_deps "${pkgs}" "${SKIP_INSTALL}"
          ;;
        # When build do not have package manager
        # Assume dependencies pre-installed
        *)
          echo "Unsupported distro: ${dist}! Package installation skipped!"
          ;;
    esac
}

parse_output() {
    # Avoid results summary lines having special characters
    sed -i -e 's/\// /g' "${RESULT_LOG}"
    sed -i -e 's/(//g' -e 's/)//g' "${RESULT_LOG}"
    sed -i -e 's/\[//g' -e 's/]//g' "${RESULT_LOG}"

    # Parse each type of results
    grep -E "OK" "${RESULT_LOG}"  2>&1 | tee "${TMP_LOG}"
    awk '{for (i=NF-3; i<NF; i++) printf $i "-"; print $i " " "pass"}' "${TMP_LOG}" 2>&1 | tee "${RESULT_FILE}"

    grep -E "FAIL" "${RESULT_LOG}" 2>&1 | tee "${TMP_LOG}"
    awk '{for (i=NF-3; i<NF; i++) printf $i "-"; print $i " " "fail"}' "${TMP_LOG}" 2>&1 | tee -a "${RESULT_FILE}"

    grep -E "SKIP" "${RESULT_LOG}" 2>&1 | tee "${TMP_LOG}"
    awk '{for (i=NF-3; i<NF; i++) printf $i "-"; print $i " " "skip"}' "${TMP_LOG}" 2>&1 | tee -a "${RESULT_FILE}"

    # Clean up
    rm -rf "${TMP_LOG}" "${RESULT_LOG}"
}

# shellcheck disable=SC2035
build_install_tests() {
    pushd "${TEST_DIR}/gtests/net/packetdrill" || exit 1
    ./configure
    make all
    mkdir -p "${INSTALL_PATH}"/"${TEST_PROGRAM}"/
    cp packetdrill "${INSTALL_PATH}"/"${TEST_PROGRAM}"/
    # Copy required files into install test program path
    cp *.py "${INSTALL_PATH}"/"${TEST_PROGRAM}"/
    cp *.sh "${INSTALL_PATH}"/"${TEST_PROGRAM}"/
    # Copy required tcp directory into install path
    cp -r ../tcp "${INSTALL_PATH}"/
    # Copy required common directory into install path
    cp -r ../common "${INSTALL_PATH}"/
    popd || exit 1
}

run_test() {
    pushd "${INSTALL_PATH}" || exit 1
    python3 ./packetdrill/run_all.py -v -l -L  2>&1 | tee -a "${RESULT_LOG}"
    popd || exit 1
}

! check_root && error_msg "This script must be run as root"
create_out_dir "${OUTPUT}"

# Install and run test
if [ "${SKIP_INSTALL}" = "true" ] || [ "${SKIP_INSTALL}" = "True" ]; then
    info_msg "Skip installing package dependency for ${TEST_PROGRAM}"
else
    install
fi

if [ ! -d "${INSTALL_PATH}" ]; then
    get_test_program "${TEST_GIT_URL}" "${TEST_DIR}" "${TEST_PROG_VERSION}" "${TEST_PROGRAM}"
    build_install_tests
fi

run_test
parse_output
