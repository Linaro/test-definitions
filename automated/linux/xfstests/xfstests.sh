#!/bin/sh
# Shell Script for Running XFS Tests

# Load required libraries
# shellcheck disable=SC1091
. ../../lib/sh-test-lib

OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE

# Results logs
RESULT_LOG="${OUTPUT}/logs.txt"
RESULT_PASS="${OUTPUT}/pass.txt"
RESULT_FAIL="${OUTPUT}/fail.txt"
RESULT_SKIP="${OUTPUT}/skip.txt"

SKIP_INSTALL="false"

# xfstests test build path
XFSTESTS_PATH="/opt/xfstests"

TEST_IMG=test.img
SCRATCH_IMG=scratch.img
TEST_DEV=/dev/loop0
SCRATCH_DEV=/dev/loop1
TEST_DIR=/mnt/test
SCRATCH_MNT=/mnt/scratch
FILESYSTEM="ext4"
T_SIZE="5G"
S_SIZE="8G"

# Print usage
usage() {
    info_msg "Usage: $0 [-d </dev/sdb>] [-e </dev/loop0>]
                           [-f <ext4>] [-m </mnt/scratch>]
                           [-t </mnt/test>] [-s <true|false>]
                           [-x <10G>] [-z <10G>] [-h]

    -d <device>     Specify the test device path (default: /dev/loop0)
    -e <device>     Specify the scratch device path (default: /dev/loop1)
    -f <filesystem> Set the filesystem type (default: ext4)
    -m <path>       Set the scratch mount path (default: /mnt/scratch)
    -t <path>       Set the test mount path (default: /mnt/test)
    -s <true>       Skip package installation (default: false)
    -x <size>       Set the test and scratch size (default: 5G for test, 8G for scratch)
    -z <size>       Set the test and scratch size (default: 5G for test, 8G for scratch)
    -h              Show this help message and exit
" 1>&2
    exit 1
}

results_parser() {
    # Parse pass test cases
    find results/*/*.full -print0 | awk -v RS='\0' -F'/' '{print $2"-"$3" pass"}' | sed 's/.full$//' >> "${RESULT_PASS}"
    # Parse fail test cases
    find results/*/*.out.bad -print0 | awk -v RS='\0' -F'/' '{print $2"-"$3" fail"}' | sed 's/.out.bad$//' >> "${RESULT_FAIL}"
    # Parse skip test cases
    find results/*/*.notrun -print0 | awk -v RS='\0' -F'/' '{print $2"-"$3" skip"}' | sed 's/.notrun$//' >> "${RESULT_SKIP}"
    # Append all the results to results.txt file
    cat "${RESULT_PASS}" "${RESULT_FAIL}" "${RESULT_SKIP}" 2>&1 | tee -a "${RESULT_FILE}"
}

# test setup
test_setup() {
    export TEST_IMG="${TEST_IMG}"
    export SCRATCH_IMG="${SCRATCH_IMG}"
    export TEST_DEV="${TEST_DEV}"
    export SCRATCH_DEV="${SCRATCH_DEV}"
    export TEST_DIR="${TEST_DIR}"
    export SCRATCH_MNT="${SCRATCH_MNT}"
    export FILESYSTEM="${FILESYSTEM}"
}

# run_xfstests ext4
run_xfstests() {
    filesystem="$1"
    info_msg "run xfstests : ${filesystem}"
    # export required configs
    test_setup
    # print disk space usage
    df
    # print mount
    mount
    if [ "${filesystem}" = "xfs" ]; then
        ./check -g "${filesystem}"/quick -x dmapi 2>&1 | tee -a "${RESULT_LOG}"
    elif [ "${filesystem}" = "ext2" ]; then
        ./check -g generic 2>&1 | tee -a "${RESULT_LOG}"
    elif [ "${filesystem}" = "ext3" ]; then
        ./check -g generic 2>&1 | tee -a "${RESULT_LOG}"
    else
        ./check -g "${filesystem}"/quick 2>&1 | tee -a "${RESULT_LOG}"
    fi
}

# format_disk_partitions "/dev/sdb" "ext4"
format_disk_partitions() {
    device="$1"
    filesystem="$2"
    info_msg "Format disk partitions of: ${device}"
    mkfs."${filesystem}" "${device}"
    exit_on_fail "format-disk-partitions"
}

# fallocate - manipulate file space
# fallocate_manipulate_file_space "/test-dir" "5G"
fallocate_manipulate_file_space() {
    img="$1"
    size="$2"
    info_msg "fallocate - manipulate file space"
    fallocate -l "${size}" "${img}"
    exit_on_fail "fallocate-l-${size}-${img}"
}

# Create fsgqa test users and groups
create_fsgqa_test_users_groups() {
    info_msg "Creating fsgqa test users and groups: "
    useradd -m fsgqa
    useradd 123456-fsgqa
    useradd fsgqa2
    groupadd fsgqa
}

while getopts "d:e:f:hm:s:t:x:z:" arg; do
    case "$arg" in
        d) TEST_DEV="${OPTARG}";;
        e) SCRATCH_DEV="${OPTARG}" ;;
        f) FILESYSTEM="${OPTARG}" ;;
        m) SCRATCH_MNT="${OPTARG}" ;;
        t) TEST_DIR="${OPTARG}" ;;
        s) SKIP_INSTALL="${OPTARG}";;
        x) T_SIZE="${OPTARG}";;
        z) S_SIZE="${OPTARG}";;
        h|*) usage ;;
    esac
done

# Test run.
! check_root && error_msg "You need to be root to run this script."
create_out_dir "${OUTPUT}"

info_msg "About to run fdisk tests ..."
info_msg "Output directory: ${OUTPUT}"

pkgs="acl attr automake bc dbench dump e2fsprogs fio gawk  gcc git indent libacl1-dev libaio-dev libcap-dev libgdbm-dev libtool libtool-bin liburing-dev libuuid1 lvm2 make psmisc python3 quota sed uuid-dev uuid-runtime xfsprogs linux-headers-$(uname -r) sqlite3 libgdbm-compat-dev"
install_deps "${pkgs}" "${SKIP_INSTALL}"

if [ -d "${XFSTESTS_PATH}" ]; then
    info_msg "xfstests found on rootfs"
    # shellcheck disable=SC2164
    cd "${XFSTESTS_PATH}" || exit 1
else
    info_msg "xfstests not found"
    error_fatal "xfstests-not-found"
fi

mkdir -p "${TEST_DIR}"
mkdir -p "${SCRATCH_MNT}"

create_fsgqa_test_users_groups

fallocate_manipulate_file_space "${TEST_IMG}" "${T_SIZE}"
fallocate_manipulate_file_space "${SCRATCH_IMG}" "${S_SIZE}"

format_disk_partitions "${TEST_IMG}" "${FILESYSTEM}"
format_disk_partitions "${SCRATCH_IMG}" "${FILESYSTEM}"

TEST_DEV=$(losetup -f "${TEST_IMG}" --show)
SCRATCH_DEV=$(losetup -f "${SCRATCH_IMG}" --show)

# Run xfstests
run_xfstests "${FILESYSTEM}"

# Parse xfstests results
results_parser
