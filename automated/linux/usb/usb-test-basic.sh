#!/bin/bash
#
# USB test cases for Linux Linaro ubuntu
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
# Author: Chase Qi <chase.qi@linaro.org>
#

set -eu
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"

usage() {
    echo "Usage: $0 [-s <true>]" 1>&2
    exit 1
}

while getopts "s:" o; do
  case "$o" in
    s) SKIP_INSTALL="${OPTARG}" ;;
    *) usage ;;
  esac
done

# Get the usb devices/hubs list
list_all_usb_devices() {
    test_case_id="lsusb"
    echo "======================================="
    info_msg "Running ${test_case_id} test..."
    eval "${test_case_id}"
    check_return "${test_case_id}"
}

# Examine all usb devices/hubs
examine_all_usb_devices() {
    echo "======================================="
    info_msg "Running examine_all_usb_devices test..."
    USB_BUS="/dev/bus/usb/"
    if [ -d "${USB_BUS}" ]; then
        for bus in $(ls "${USB_BUS}"); do
            for device in $(ls "${USB_BUS}"$bus/); do
                echo "======================================="
                info_msg "USB Bus "${bus}", device "${device}""
                echo "======================================="
                lsusb -D "${USB_BUS}"$bus/$device
                check_return "USB_Bus"${bus}"_Device"${device}"_examination"
            done
        done
    else
        echo "examine_all_usb_devices fail" | tee -a "${RESULT_FILE}"
    fi
}

# Print supported usb protocols
print_supported_usb_protocols() {
    echo "======================================="
    info_msg "Running print_supported_usb_protocols test..."
    if [ -z "`lsusb -v | grep -i bcdusb`" ]; then
        echo "print_supported_usb_protocols fail" | tee -a "${RESULT_FILE}"
    else
        lsusb -v | grep -i bcdusb | sort | uniq
        echo "print_supported_usb_protocols pass" | tee -a "${RESULT_FILE}"
    fi
}

# Print supported usb speeds
print_supported_usb_speeds() {
    echo "======================================="
    info_msg "Running print_supported_usb_speeds test..."
    if [ -z "`lsusb -t`" ]; then
        echo "print_supported_usb_speeds fail" | tee -a "${RESULT_FILE}"
    else
        lsusb -t
        echo "print_supported_usb_speeds pass" | tee -a "${RESULT_FILE}"
    fi
}

# Test run.
! check_root && error_msg "This script must be run as root"
[ -d "${OUTPUT}" ] && mv "${OUTPUT}" "${OUTPUT}_$(date +%Y%m%d%H%M%S)"
mkdir -p "${OUTPUT}"

info_msg "About to run USB test..."
info_msg "Output directory: ${OUTPUT}"

# Install usbutils package
pkgs="usbutils"
install_deps "${pkgs}" "${SKIP_INSTALL}"

list_all_usb_devices
examine_all_usb_devices
print_supported_usb_protocols
print_supported_usb_speeds
