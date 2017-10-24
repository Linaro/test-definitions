#!/bin/sh
#
# WLAN smoke tests
#
# Copyright (C) 2017, Linaro Limited.
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
# Author: Nicolas Dechesne <nicolas.dechesne@linaro.org>
#

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE
DEVICE="wlan0"
BOOT="enabled"

usage() {
    echo "Usage: $0 [-b <enabled|disabled>] [-d <device>]" 1>&2
    exit 1
}

while getopts "d:b:" o; do
  case "$o" in
    d) DEVICE="${OPTARG}" ;;
    b) BOOT="${OPTARG}" ;;
    *) usage ;;
  esac
done

# sanity test ip command
test_iplink() {
    info_msg "Running ip link test..."
    ip link show "${DEVICE}"
    exit_on_fail "ip-link"
}

# test WLAN device at boot is $BOOT
test_wlan_boot() {
    info_msg "Running wlan boot test..."
    if [ "${BOOT}" = "enabled" ]; then
        ip link show "${DEVICE}" | grep "${DEVICE}" | grep "UP"
    else
        ip link show "${DEVICE}" | grep "${DEVICE}" | grep -v "UP"
    fi
    check_return "wlan-boot"
}

# test WLAN device is up
test_wlan_up() {
    info_msg "Running wlan-up test..."
    ip link set "${DEVICE}" up
    sleep 1
    ip link show "${DEVICE}" | grep "${DEVICE}" | grep "UP"
    check_return "wlan-up"
}

# test WLAN device is down
test_wlan_down() {
    info_msg "Running wlan-down test..."
    ip link set "${DEVICE}" down
    sleep 1
    ip link show "${DEVICE}" | grep "${DEVICE}" | grep -v "UP"
    check_return "wlan-down"
}

# Test run.
! check_root && error_msg "This script must be run as root"
create_out_dir "${OUTPUT}"

info_msg "About to run wlan smoke test..."
info_msg "Output directory: ${OUTPUT}"

# ensure that device is available at boot
test_iplink
test_wlan_boot
test_wlan_down
test_wlan_up




