#!/bin/sh

# shellcheck disable=SC1091
. ../../lib/sh-test-lib

OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE
SKIP_INSTALL="false"

DEVICE=""
FILESYSTEM="ext4"
SIZES=""

usage() {
    echo "Usage: $0 [-d </dev/sdb>]
                    [-f <ext4>]
                    [-s <true|false>]
                    [-z <+10G +5G>]" 1>&2
    exit 1
}

# create_partitions "/dev/sdb" "+5G +5G"
create_partitions() {
    echo
    echo "Creating partition: ${DEVICE}"
    skip_list="format-partitions"
    partition_disk "${DEVICE}" "${SIZES}"
    exit_on_fail "create-partitions" "${skip_list}"
}

# format_partitions "/dev/sdb" "ext4"
format_partitions() {
    echo
    echo "Format partitions of: ${DEVICE}"
    format_partition "${DEVICE}" "${FILESYSTEM}"
    exit_on_fail "format-partitions"
}

while getopts "d:f:s:z:" arg; do
   case "$arg" in
     d) DEVICE="${OPTARG}";;
     f) FILESYSTEM="${OPTARG}" ;;
     # SKIP_INSTALL is true in case of Open Embedded builds
     # SKIP_INSTALL is false in case of Debian builds
     s) SKIP_INSTALL="${OPTARG}";;
     z) SIZES="${OPTARG}";;
     *) usage ;;
  esac
done

# Test run.
[ -b "${DEVICE}" ] || error_msg "Please specify a block device with '-d'"
! check_root && error_msg "You need to be root to run this script."
create_out_dir "${OUTPUT}"

info_msg "About to run fdisk tests ..."
info_msg "Output directory: ${OUTPUT}"

pkgs="fdisk e2fsprogs dosfstools"
install_deps "${pkgs}" "${SKIP_INSTALL}"

create_partitions
format_partitions
