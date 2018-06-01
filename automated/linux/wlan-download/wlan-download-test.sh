#!/bin/sh
#
# WLAN download test
#
# Copyright (C) 2018, Linaro Limited.
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
# Author: Anibal Limon <anibal.limon@linaro.org>
#

# shellcheck disable=SC1091
# shellcheck disable=SC2046
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE
DEVICE="wlan0"
SSID_NAME=""
SSID_PASSWORD=""
FILE_URL=""
FILE_CHECKSUM=""

usage() {
    echo "Usage: $0 [-d device] <-s ssid_name> <-p ssid_password> [-u file_url] [-c file_checksum]" 1>&2
    exit 1
}

while getopts "d:s:p:u:c:" o; do
  case "$o" in
    d) DEVICE="${OPTARG}" ;;
    s) SSID_NAME="${OPTARG}" ;;
    p) SSID_PASSWORD="${OPTARG}" ;;
    u) FILE_URL="${OPTARG}" ;;
    c) FILE_CHECKSUM="${OPTARG}" ;;
    *) usage ;;
  esac
done

if [ -z "${SSID_NAME}" ] || [ -z "${SSID_PASSWORD}" ]; then
	usage
fi

# test WLAN device connection
test_wlan_connection() {
    info_msg "Running wlan connect test..."
    nmcli device wifi connect "${SSID_NAME}" password "${SSID_PASSWORD}" ifname "${DEVICE}"
    nmcli device | grep "${DEVICE}" | grep "[[:space:]]connected"
    exit_on_fail "wlan-connect"
}

# test WLAN download
test_wlan_download() {
    info_msg "Running wlan download test..."
    curl -O --interface "${DEVICE}" "${FILE_URL}"
    check_return "wlan-download"
    local_file=$(basename "${FILE_URL}")
    local_md5=$(md5sum $(basename "${local_file}") | awk '{print $1}')
    test "${local_md5}" = "${FILE_CHECKSUM}"
    check_return "wlan-download-checksum"
    rm -f "${local_file}"
}

# Test run.
! check_root && error_msg "This script must be run as root"
create_out_dir "${OUTPUT}"

info_msg "About to run wlan download test..."
info_msg "Output directory: ${OUTPUT}"

test_wlan_connection
if [ ! -z "${FILE_URL}" ]; then
    test_wlan_download
fi

nmcli connection delete "${SSID_NAME}"
check_return "wlan-disconnect"
