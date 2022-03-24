#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2021 Foundries.io Ltd.

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE
MOUNTPOINT=sysroot
SKIP_INSTALL="True"

usage() {
    echo "\
    Usage: $0
             [-m <sysroot>]
             [-s <True|False>]

    -m <sysroot>
        This is the name of the mountpoint to be tested.
    -s <True|False>
        Omit dependency installation. In this case it's util-linux package
    -h
        Display this message
    "
}

while getopts "s:m:h" opts; do
    case "$opts" in
        m) MOUNTPOINT="${OPTARG}";;
        s) SKIP_INSTALL="${OPTARG}" ;;
        h|*) usage ; exit 1 ;;
    esac
done

if [ "$SKIP_INSTALL" = 'true' ] || [ "$SKIP_INSTALL" = 'True' ]; then
    warn_msg "Dependencies installation skipped!"
else
    dist_name
    # shellcheck disable=SC2154
    case "${dist}" in
        debian|ubuntu)
            install_deps "util-linux"
            ;;
        fedora|centos)
            install_deps "util-linux-ng"
            ;;
    esac
fi
create_out_dir "${OUTPUT}"
INODES=$(df --output=itotal,size,target | grep "$MOUNTPOINT" | xargs echo -n | cut -d " " -f 1)
echo "Inodes: $INODES"
BLOCKS=$(df --output=itotal,size,target | grep "$MOUNTPOINT" | xargs echo -n | cut -d " " -f 2)
echo "1k Blocks: $BLOCKS"
DISK_SIZE=$(lsblk -b -o SIZE,MOUNTPOINT | grep "$MOUNTPOINT" | xargs echo -n | cut -d " " -f 1)
echo "Disk Size (bytes): $DISK_SIZE"
# Subtract inode table and fs size from disk size. Result should be withing 1%

RESULT=$(echo "${DISK_SIZE}-(${INODES}*256)-(${BLOCKS}*1024) > ${DISK_SIZE}*0.01"|bc)
# shellcheck disable=SC2086
if [ $RESULT ]; then
    report_pass "disk-resize-test"
else
    report_fail "disk-resize-test"
fi
