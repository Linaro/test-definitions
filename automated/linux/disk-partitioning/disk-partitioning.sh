#!/bin/sh

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE
DISKLABEL="gpt"
FILESYSTEM="ext4"

usage() {
    echo "Usage: $0 [-d <device>] [-l <disklabel>] [-f <filesystem>] [-s <true|false>]" 1>&2
    exit 1
}

while getopts "d:l:f:r:s:" o; do
  case "$o" in
    # The existing disk label on the device will be destroyed,
    # and all data on this disk will be lost.
    d) DEVICE="${OPTARG}" ;;
    l) DISKLABEL="${OPTARG}" ;;
    f) FILESYSTEM="${OPTARG}" ;;
    s) SKIP_INSTALL="${OPTARG}" ;;
    *) usage ;;
  esac
done

create_disklabel() {
    echo
    echo "Creating ${DEVICE} disklabel: ${DISKLABEL}"
    umount "${DEVICE}*" > /dev/null 2>&1
    # If mklabel fails, skip the following tests.
    skip_list="create-partition format-partition mount-partition umount-partition"
    parted -s "${DEVICE}" mklabel "${DISKLABEL}"
    exit_on_fail "create-disklabel" "${skip_list}"

    sync
    sleep 10
}

create_partition() {
    echo
    echo "Creating partition: ${DEVICE}1"
    skip_list="format-partition mount-partition umount-partition"
    parted -s "${DEVICE}" mkpart primary 0% 100%
    exit_on_fail "create-partition" "${skip_list}"

    sync
    sleep 10
}

format_partition() {
    echo
    echo "Formatting ${DEVICE}1 to ${FILESYSTEM}"
    skip_list="mount-partition umount-partition"
    if [ "${FILESYSTEM}" = "fat32" ]; then
        echo "y" | mkfs -t vfat -F 32 "${DEVICE}1"
    else
        echo "y" | mkfs -t "${FILESYSTEM}" "${DEVICE}1"
    fi
    exit_on_fail "format-partition" "${skip_list}"

    sync
    sleep 10
}

disk_mount() {
    echo
    echo "Running mount/umount tests..."
    umount /mnt > /dev/null 2>&1
    skip_list="umount-partition"
    mount "${DEVICE}1" /mnt
    exit_on_fail "mount-partition" "${skip_list}"

    umount "${DEVICE}1"
    check_return "umount-partition"
}

# Test run.
[ -b "${DEVICE}" ] || error_msg "Please specify a block device with '-d'"
! check_root && error_msg "You need to be root to run this script."
create_out_dir "${OUTPUT}"

pkgs="parted e2fsprogs dosfstools"
install_deps "${pkgs}" "${SKIP_INSTALL}"

create_disklabel
create_partition
format_partition
disk_mount
