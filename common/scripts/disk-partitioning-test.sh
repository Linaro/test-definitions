#!/bin/sh
#
# Disk partitioning test.
#
# Copyright (C) 2010 - 2016, Linaro Limited.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# Author: Chase Qi <chase.qi@linaro.org>

LANG=C
export LANG
. ./common/scripts/include/sh-test-lib
WD="$(pwd)"
RESULT_FILE="${WD}/disk-partitioning-test-result.txt"
DISKLABEL="gpt"
FILESYSTEM="ext4"
SKIP_INSTALL="false"

usage() {
    echo "Usage: $0 [-d <device>] [-l <disklabel>] [-f <filesystem>]
          [-r <result_file>] [-s <true|false>]" 1>&2
    exit 1
}

while getopts "d:l:f:r:s:" o; do
  case "$o" in
    # The existing disk label on the device will be destroyed,
    # and all data on this disk will be lost.
    d) DEVICE="${OPTARG}" ;;
    l) DISKLABEL="${OPTARG}" ;;
    f) FILESYSTEM="${OPTARG}" ;;
    r) RESULT_FILE="${WD}/${OPTARG}" ;;
    s) SKIP_INSTALL="${OPTARG}" ;;
    *) usage ;;
  esac
done

[ -z "${DEVICE}" ] && error_msg "Please specify test device with '-d'"
DISKLABEL=${DISKLABEL:-"gpt"}
FILESYSTEM=${FILESYSTEM:-"ext4"}
SKIP_INSTALL=${SKIP_INSTALL:-"false"}

install() {
    if "${SKIP_INSTALL}"; then
        info_msg "install_deps skipped"
    else
        pkgs="parted e2fsprogs dosfstools"
        info_msg "Installing ${pkgs}"
        install_deps "${pkgs}"
    fi
}

create_disklabel() {
    echo
    echo "Creating ${DEVICE} disklabel: ${DISKLABEL}"
    umount "${DEVICE}*" > /dev/null 2>&1
    parted -s "${DEVICE}" mklabel "${DISKLABEL}"

    # Collect test reuslt with check_return function.
    # If mklabel fails, skip the following tests.
    check_return "create-disklabel" \
        || error_msg "Partitioning, formatting, and smoke tests skipped"

    sync
    sleep 10
}

create_partition() {
    echo
    echo "Creating partition: ${DEVICE}1"
    parted -s "${DEVICE}" mkpart primary 0% 100%

    check_return "create-partition" \
        || error_msg "Formatting, and smoke tests skipped"

    sync
    sleep 10
}

format_partition() {
    echo
    echo "Formatting ${DEVICE}1 to ${FILESYSTEM}"
    if [ "${FILESYSTEM}" = "fat32" ]; then
        echo "y" | mkfs -t vfat -F 32 "${DEVICE}1"
    else
        echo "y" | mkfs -t "${FILESYSTEM}" "${DEVICE}1"
    fi

    check_return "format-partition" || error_msg "Smoke test skipped"

    sync
    sleep 10
}

partition_smoke_test() {
    echo
    echo "Running mount/umoun tests..."
    umount /mnt > /dev/null 2>&1
    mount "${DEVICE}1" /mnt
    check_return "mount-partition" || error_msg "umount test skipped"

    umount "${DEVICE}1"
    check_return "umount-partition"
}

# Test run.
! check_root && error_msg "This script must be run as root"
[ -f "${RESULT_FILE}" ] \
     && mv "${RESULT_FILE}" "${RESULT_FILE}_$(date +%Y%m%d%H%M%S)"

echo
info_msg "About to run disk partitioning test..."
info_msg "Working directory: ${WD}"
info_msg "Result will be saved to: ${RESULT_FILE}"

install
create_disklabel
create_partition
format_partition
partition_smoke_test
