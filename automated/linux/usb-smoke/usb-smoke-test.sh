#!/bin/sh
#
# USB smoke test cases
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
# Author: Naresh Kamboju <naresh.kamboju@linaro.org>
#

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE
STATUS=0

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

increment_return_status() {
    exit_code="$?"
    [ "$#" -ne 1 ] && error_msg "Usage: increment_return_status value"
    value="$1"
    return "$((exit_code+value))"
}

# Get the usb devices/hubs list
list_all_usb_devices() {
    info_msg "Running list-all-usb-devices test..."
    lsusb
    exit_on_fail "lsusb"
}

# Examine all usb devices/hubs
examine_all_usb_devices() {
    info_msg "Running examine_all_usb_devices test..."
    USB_BUS="/dev/bus/usb/"
    if [ -d "${USB_BUS}" ]; then
	# shellcheck disable=SC2045
        for bus in $(ls "${USB_BUS}"); do
	    # shellcheck disable=SC2045
            for device in $(ls "${USB_BUS}""${bus}"/); do
                info_msg "USB Bus ${bus}, device ${device}"
                lsusb -D "${USB_BUS}""${bus}"/"${device}"
                increment_return_status "${STATUS}"
                STATUS=$?
            done
        done
        if [ "${STATUS}" -ne 0 ]; then
            report_fail "examine-all-usb-devices"
        else
            report_pass "examine-all-usb-devices"
        fi
    else
        report_fail "examine-all-usb-devices"
    fi
}

# Print supported usb protocols
print_supported_usb_protocols() {
    info_msg "Running print-supported-usb-protocols test..."
    lsusb -v | grep -i bcdusb
    check_return "print-supported-usb-protocols"
}

# Print supported usb speeds
print_supported_usb_speeds() {
    info_msg "Running print-supported-usb-speeds test..."
    lsusb -t
    check_return "print-supported-usb-speeds"
}

# Test run.
! check_root && error_msg "This script must be run as root"
create_out_dir "${OUTPUT}"

info_msg "About to run USB test..."
info_msg "Output directory: ${OUTPUT}"

# Install usbutils package
pkgs="usbutils"
install_deps "${pkgs}" "${SKIP_INSTALL}"

list_all_usb_devices
examine_all_usb_devices
print_supported_usb_protocols
print_supported_usb_speeds
