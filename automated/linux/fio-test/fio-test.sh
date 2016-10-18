#!/bin/bash
#
# FIO test cases for Linux
#
# Copyright (C) 2016, Linaro Limited.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# Author: Naresh Kamboju <naresh.kamboju@linaro.org>
#

. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
FIO_SKIP_LIST="fio_read fio_randread fio_write fio_randwrite fio_512k_write fio_512k_read"

usage() {
    echo "Usage: $0 [-p <partition>] [-s <true>]" 1>&2
    exit 1
}

while getopts "p:s:" o; do
  case "$o" in
    # The current working directory will be used by default.
    # Use '-p' specify partition that used for dd test.
    p) PARTITION="${OPTARG}" ;;
    s) SKIP_INSTALL="${OPTARG}" ;;
    *) usage ;;
  esac
done

fio_build_install() {
    wget http://brick.kernel.dk/snaps/fio-2.1.10.tar.gz
    tar -xvf fio-2.1.10.tar.gz
    cd fio-2.1.10
    ./configure
    make all
    make install
}

install() {
    dist_name
    case "${dist}" in
      Debian|Ubuntu)
        pkgs="fio"
        install_deps "${pkgs}" "${SKIP_INSTALL}"
        ;;
      Fedora|CentOS)
        pkgs="gcc tar wget"
        install_deps "${pkgs}" "${SKIP_INSTALL}"
        fio_build_install
        ;;
      *) fio_build_install ;;
    esac
}

parse_output() {
    test="$1"
    file="$2"
    IOPS=$(grep "iops=" "${file}" | cut -d= -f4 | cut -d, -f1)
    add_metric "${test}" "pass" "${IOPS}" "iops"
}

fio_device_existence() {
    # check for block device
    [ -b "${PARTITION}" ]
    exit_on_fail "fio_device" "fio ${FIO_SKIP_LIST}"
}

fio_existence() {
    eval "which fio"
    exit_on_fail "fio" "${FIO_SKIP_LIST}"
}

fio_read() {
    file="${OUTPUT}/fio_read.txt"
    fio -filename="${PARTITION}" -rw=read -direct=1 -iodepth 1 -thread \
        -ioengine=psync -bs=4k -numjobs=1 -runtime=10 -group_reporting \
        -name=fio_read 2>&1 | tee -a "${file}"
    parse_output "fio_read" "${file}"

}

fio_randread() {
    file="${OUTPUT}/fio_randread.txt"
    fio -filename="${PARTITION}" -rw=randread -direct=1 -iodepth 1 -thread \
        -ioengine=psync -bs=4k -numjobs=1 -runtime=10 -group_reporting \
        -name=fio_randread 2>&1 | tee -a "${file}"
    parse_output "fio_randread" "${file}"
}

fio_write() {
    file="${OUTPUT}/fio_write.txt"
    fio -filename="${PARTITION}" -rw=write -direct=1 -iodepth 1 -thread \
        -ioengine=psync -bs=4k -numjobs=1 -runtime=10 -group_reporting \
        -name=fio_write 2>&1 | tee -a "${file}"
    parse_output "fio_write" "${file}"
}

fio_randwrite() {
    file="${OUTPUT}/fio_randwrite.txt"
    fio -filename="${PARTITION}" -rw=randwrite -direct=1 -iodepth 1 -thread \
        -ioengine=psync -bs=4k -numjobs=1 -runtime=10 -group_reporting \
        -name=fio_randwrite 2>&1 | tee -a "${file}"
    parse_output "fio_randwrite" "${file}"
}

fio_512k_write() {
    file="${OUTPUT}/fio_512k_write.txt"
    fio -filename="${PARTITION}" -rw=write -direct=1 -iodepth 1 -thread \
        -ioengine=psync -bs=512k -numjobs=1 -runtime=10 -group_reporting \
        -name=fio_512k_write 2>&1 | tee -a "${file}"
    parse_output "fio_512k_write" "${file}"
}

fio_512k_read() {
    file="${OUTPUT}/fio_512k_read.txt"
    fio -filename="${PARTITION}" -rw=read -direct=1 -iodepth 1 -thread \
        -ioengine=psync -bs=512k -numjobs=1 -runtime=10 -group_reporting \
        -name=fio_512k_read 2>&1 | tee -a "${file}"
    parse_output "fio_512k_read" "${file}"
}

# Test run.
! check_root && error_msg "This script must be run as root"
[ -d "${OUTPUT}" ] && mv "${OUTPUT}" "${OUTPUT}_$(date +%Y%m%d%H%M%S)"
mkdir -p "${OUTPUT}"

info_msg "About to run fio test..."
info_msg "Output directory: ${OUTPUT}"

# Install dependency packages
install

# Run all test
fio_device_existence
fio_existence
fio_read
fio_randread
fio_write
fio_randwrite
fio_512k_write
fio_512k_read
