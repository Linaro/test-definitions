#!/bin/sh
#
# HCI smoke tests
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
DEVICE="hci0"
BOOT="enabled"

# Pattern for HCI device baddr
BADDR_PATTERN="..:..:..:..:..:.."

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

# sanity test hciconfig config
test_hciconfig() {
    info_msg "Running hciconfig test..."
    hciconfig "${DEVICE}"
    exit_on_fail "hciconfig"
}

# test HCI device is $BOOT at boot
test_hciconfig_boot() {
    info_msg "Running hciconfig_boot test..."

    # rely on distro policy for AutoEnable
    if [ "${BOOT}" = "auto" ]; then
        # get rid of spaces and comments
        sed 's/\s\+//g;/^#/d' /etc/bluetooth/main.conf | grep "^AutoEnable=true"
	# shellcheck disable=SC2181
        if [ "$?" -eq 0 ]; then
            BOOT="enabled"
        else
            BOOT="disabled"
        fi
    fi

    if [ "${BOOT}" = "enabled" ]; then
        hciconfig "${DEVICE}" | grep "UP RUNNING"
    else
        hciconfig "${DEVICE}" | grep "DOWN"
    fi
    check_return "hciconfig-boot-${BOOT}"
}

# test HCI device is up
test_hciconfig_up() {
    info_msg "Running hciconfig-up test..."
    hciconfig "${DEVICE}" up
    sleep 1
    hciconfig "${DEVICE}" | grep "UP RUNNING"
    check_return "hciconfig-up"
}

test_hciconfig_down() {
    info_msg "Running hciconfig-down test..."
    hciconfig "${DEVICE}" down
    sleep 1
    hciconfig "${DEVICE}" | grep DOWN
    check_return "hciconfig-down"
}

# Test HCI device scanning
test_hcitool_scan() {
    info_msg "Running hcitool-scan test..."
    hcitool -i "${DEVICE}" scan
    check_return "hciconfig-scan"
    hcitool -i "${DEVICE}" scan | grep $BADDR_PATTERN
    check_return "hciconfig-scan-verify-available-devices"
}

# Test HCI device inquiry
test_hcitool_inq() {
    info_msg "Running hcitool-inq test..."
    hcitool -i "${DEVICE}" inq
    check_return "hciconfig-inq"
    hcitool -i "${DEVICE}" inq | grep $BADDR_PATTERN
    check_return "hciconfig-inq-verify-available-devices"
}

# Test run.
! check_root && error_msg "This script must be run as root"
create_out_dir "${OUTPUT}"

info_msg "About to run HCI smoke test..."
info_msg "Output directory: ${OUTPUT}"

# ensure that device is available at boot
test_hciconfig
test_hciconfig_boot
test_hciconfig_down
test_hciconfig_up
test_hcitool_scan
test_hcitool_inq

exit 0
