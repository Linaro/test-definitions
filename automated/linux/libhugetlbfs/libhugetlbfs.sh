#!/bin/sh

# shellcheck disable=SC1091
. ../../lib/sh-test-lib

OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
RESULT_LOG="${OUTPUT}/result_log.txt"
TEST_PASS_LOG="${OUTPUT}/test_pass_log.txt"
TEST_FAIL_LOG="${OUTPUT}/test_fail_log.txt"
TEST_SKIP_LOG="${OUTPUT}/test_skip_log.txt"

WORD_SIZE="64"
VERSION="2.20"

usage() {
    echo "Usage: $0 [-b <4|64>] [-s <true>] [-v <libhugetlbfs-version>]" 1>&2
    exit 1
}

while getopts "b:s:v:" o; do
  case "$o" in
    b) WORD_SIZE="${OPTARG}" ;;
    s) SKIP_INSTALL="${OPTARG}" ;;
    v) VERSION="${OPTARG}" ;;
    *) usage ;;
  esac
done

parse_output() {
    # Parse each type of results
    egrep "*:.*PASS" "${RESULT_LOG}"  2>&1 | tee -a "${TEST_PASS_LOG}"
    sed -i -e 's/ (inconclusive)//g' "${TEST_PASS_LOG}"
    sed -i -e 's/(//g' "${TEST_PASS_LOG}"
    sed -i -e 's/)://g' "${TEST_PASS_LOG}"
    sed -i -e 's/://g' "${TEST_PASS_LOG}"
    awk '{for (i=1; i<NF-1; i++) printf $i "-"; print $i " " $NF}' "${TEST_PASS_LOG}" 2>&1 | tee -a "${RESULT_FILE}"

    egrep "*:.*FAIL" "${RESULT_LOG}" | cut -d: -f 1-2 2>&1 | tee -a "${TEST_FAIL_LOG}"
    sed -i -e 's/ (inconclusive)//g' "${TEST_FAIL_LOG}"
    sed -i -e 's/(//g' "${TEST_FAIL_LOG}"
    sed -i -e 's/)//g' "${TEST_FAIL_LOG}"
    sed -i -e 's/://g' "${TEST_FAIL_LOG}"
    awk '{for (i=1; i<NF; i++) printf $i "-"; print $i " " "FAIL"}' "${TEST_FAIL_LOG}" 2>&1 | tee -a "${RESULT_FILE}"

    egrep "*:.*SKIP" "${RESULT_LOG}" | cut -d: -f 1-2 2>&1 | tee -a "${TEST_SKIP_LOG}"
    egrep "*:.*Bad configuration" "${RESULT_LOG}" | cut -d: -f 1-2 2>&1 | tee -a "${TEST_SKIP_LOG}"
    sed -i -e 's/ (inconclusive)//g' "${TEST_SKIP_LOG}"
    sed -i -e 's/(//g' "${TEST_SKIP_LOG}"
    sed -i -e 's/)//g' "${TEST_SKIP_LOG}"
    sed -i -e 's/://g' "${TEST_SKIP_LOG}"
    awk '{for (i=1; i<NF; i++) printf $i "-"; print $i " " "SKIP"}' "${TEST_SKIP_LOG}" 2>&1 | tee -a "${RESULT_FILE}"
}

libhugetlbfs_build_test() {
    mount_point="/mnt/hugetlb/"
    # Allocate hugepages
    echo 200 > /proc/sys/vm/nr_hugepages
    umount "${mount_point}" > /dev/null 2>&1 || true
    mkdir -p "${mount_point}"
    mount -t hugetlbfs hugetlbfs "${mount_point}"

    # shellcheck disable=SC2140
    wget https://github.com/libhugetlbfs/libhugetlbfs/releases/download/"${VERSION}"/libhugetlbfs-"${VERSION}".tar.gz
    tar -xvf libhugetlbfs-"${VERSION}".tar.gz
    # shellcheck disable=SC2164
    cd libhugetlbfs-"${VERSION}"
    make BUILDTYPE=NATIVEONLY
    # shellcheck disable=SC2164
    cd tests
    # Run tests
    # Redirect stdout (not stderr)
    ./run_tests.py -b "${WORD_SIZE}" | tee -a "${RESULT_LOG}"
    parse_output
    umount "${mount_point}" > /dev/null 2>&1 || true
}

install() {
    dist_name
    # shellcheck disable=SC2154
    case "${dist}" in
      Debian|Ubuntu)
        pkgs="binutils gcc make python sed tar wget"
        install_deps "${pkgs}" "${SKIP_INSTALL}"
        ;;
      Fedora|CentOS)
        pkgs="binutils gcc make python sed tar wget"
        install_deps "${pkgs}" "${SKIP_INSTALL}"
        ;;
    esac
}

# Test run.
! check_root && error_msg "This script must be run as root"
[ -d "${OUTPUT}" ] && mv "${OUTPUT}" "${OUTPUT}_$(date +%Y%m%d%H%M%S)"
mkdir -p "${OUTPUT}"

info_msg "About to run libhugetlbfs test..."
info_msg "Output directory: ${OUTPUT}"


CONFIG_HUGETLBFS=$(zcat /proc/config.gz | grep "CONFIG_HUGETLBFS=")
CONFIG_HUGETLB_PAGE=$(zcat /proc/config.gz | grep "CONFIG_HUGETLB_PAGE=")
HUGETLBFS=$(grep hugetlbfs /proc/filesystems | awk '{print $2}')

[ "${CONFIG_HUGETLBFS}" = "CONFIG_HUGETLBFS=y" ] && [ "${CONFIG_HUGETLB_PAGE}" = "CONFIG_HUGETLB_PAGE=y" ] && [ "${HUGETLBFS}" = "hugetlbfs" ]
exit_on_skip "libhugetlb" "Kernel config CONFIG_HUGETLBFS=y and CONFIG_HUGETLB_PAGE=y not enabled"

# Install packages
install

# Build libhugetlbfs and run tests
libhugetlbfs_build_test
