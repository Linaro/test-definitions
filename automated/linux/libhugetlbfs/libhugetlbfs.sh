#!/bin/sh

# shellcheck disable=SC1091
. ../../lib/sh-test-lib

OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
RESULT_LOG="${OUTPUT}/result_log.txt"
TEST_LOG="${OUTPUT}/test_log.txt"

usage() {
    echo "Usage: $0 [-b <4|64>] [-s <true>]" 1>&2
    exit 1
}

while getopts "b:s:" o; do
  case "$o" in
    b) WORD_SIZE="${OPTARG}" ;;
    s) SKIP_INSTALL="${OPTARG}" ;;
    *) usage ;;
  esac
done

parse_output() {
    egrep "PASS|FAIL" "${RESULT_LOG}"  2>&1 | tee -a "${TEST_LOG}"
    sed -i -e 's/ (inconclusive)//g' "${TEST_LOG}"
    sed -i -e 's/(//g' "${TEST_LOG}"
    sed -i -e 's/)://g' "${TEST_LOG}"
    sed -i -e 's/://g' "${TEST_LOG}"
    awk '{for (i=1; i<NF-1; i++) printf $i "-"; print $i " " $NF}' "${TEST_LOG}" 2>&1 | tee -a "${RESULT_FILE}"
}

libhugetlbfs_build_test() {
    mount_point="/mnt/hugetlb/"
    # Allocate hugepages
    echo 200 > /proc/sys/vm/nr_hugepages
    umount "${mount_point}" > /dev/null 2>&1 || true
    mkdir -p "${mount_point}"
    mount -t hugetlbfs hugetlbfs "${mount_point}"

    wget https://github.com/libhugetlbfs/libhugetlbfs/releases/download/2.20/libhugetlbfs-2.20.tar.gz
    tar -xvf libhugetlbfs-2.20.tar.gz
    cd libhugetlbfs-2.20
    make BUILDTYPE=NATIVEONLY
    cd tests
    # Run tests
    # Redirect stdout (not stderr)
    ./run_tests.py -b "${WORD_SIZE}" | tee -a "${RESULT_LOG}"
    parse_output
    umount "${mount_point}" > /dev/null 2>&1 || true
}

install() {
    dist_name
    case "${dist}" in
      Debian|Ubuntu)
        pkgs="aptitude binutils tar wget"
        install_deps "${pkgs}" "${SKIP_INSTALL}"
        ;;
      Fedora|CentOS)
        pkgs="binutils gcc make tar wget"
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
exit_on_fail "libhugetlb-config"

# Install packages
install

# Build libhugetlbfs and run tests
libhugetlbfs_build_test
