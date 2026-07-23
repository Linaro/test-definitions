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

# shellcheck disable=SC1091,SC2034,SC2039
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE
DEVICE=""
BOOT="enabled"
WAIT_TIME=0

usage() {
    echo "Usage: $0 [-b <enabled|disabled>] [-d <device>] [-w <wait_time>]" 1>&2
    exit 1
}

while getopts "d:b:w:" o; do
  case "$o" in
    d) DEVICE="${OPTARG}" ;;
    b) BOOT="${OPTARG}" ;;
    w) WAIT_TIME="${OPTARG}" ;;
    *) usage ;;
  esac
done

# list wireless interfaces, one per line
list_wlan_devices() {
    for dev in /sys/class/net/*/wireless; do
        [ -d "${dev}" ] || continue
        basename "$(dirname "${dev}")"
    done
}

# sanity test ip command
test_iplink() {
    local device="$1"
    info_msg "Running ip link test on ${device}..."
    ip link show "${device}"
    check_return "ip-link"
}

# test WLAN device at boot is $BOOT
test_wlan_boot() {
    local device="$1"
    info_msg "Running wlan boot test on ${device}..."
    if [ "${BOOT}" = "enabled" ]; then
        ip link show "${device}" | grep "${device}" | grep "UP"
    else
        ip link show "${device}" | grep "${device}" | grep -v "UP"
    fi
    check_return "wlan-boot"
}

# test WLAN device is up
test_wlan_up() {
    local device="$1"
    info_msg "Running wlan-up test on ${device}..."
    ip link set "${device}" up
    sleep 1
    ip link show "${device}" | grep "${device}" | grep "UP"
    check_return "wlan-up"
}

# test WLAN device is down
test_wlan_down() {
    local device="$1"
    info_msg "Running wlan-down test on ${device}..."
    ip link set "${device}" down
    sleep 1
    ip link show "${device}" | grep "${device}" | grep -v "UP"
    check_return "wlan-down"
}

# helper function to wait for wifi device(s) to come up. When DEVICE is
# unset, wait for any wireless interface to be enumerated.
wait_for_device() {
    info_msg "Waiting ${WAIT_TIME} seconds for requested device to exist..."
    for i in $(seq 1 "${WAIT_TIME}")
    do
      if [ -n "${DEVICE}" ]; then
          ip link show "${DEVICE}" > /dev/null 2>&1 && break
      else
          [ -n "$(list_wlan_devices)" ] && break
      fi
      sleep 1
    done
}

# Test run.
! check_root && error_msg "This script must be run as root"
create_out_dir "${OUTPUT}"

info_msg "About to run wlan smoke test..."
info_msg "Output directory: ${OUTPUT}"

# ensure that device(s) are available at boot
wait_for_device

# use the explicitly requested device, or auto-detect all wireless
# interfaces present on the DUT
devices="${DEVICE:-$(list_wlan_devices)}"

if [ -z "${devices}" ]; then
    report_skip "wlan-device-exists"
    exit 0
fi
report_pass "wlan-device-exists"

# keep plain test case names so results stay comparable across runs; when
# several interfaces are tested, wrap each one in its own test set to keep
# the names unique
multiple="false"
[ "$(echo "${devices}" | wc -l)" -gt 1 ] && multiple="true"

for device in ${devices}; do
    [ "${multiple}" = "true" ] && report_set_start "${device}"
    test_iplink "${device}"
    test_wlan_boot "${device}"
    test_wlan_down "${device}"
    test_wlan_up "${device}"
    [ "${multiple}" = "true" ] && report_set_stop
done

exit 0
