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

set -x

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE
DEVICE="wlan0"
ETHERNET_DEVICE=""
SSID_NAME=""
SSID_PASSWORD=""
FILE_URL=""
FILE_CHECKSUM=""
TIME_DELAY="0s"
NAMESERVER=""

usage() {
    echo "Usage: $0 <-s ssid_name> <-p ssid_password> [-d device] [-e ethernet_device] [-u file_url] [-c file_checksum] [-t time_delay] [-n nameserver]" 1>&2
    exit 1
}

while getopts "d:e:s:p:u:c:t:n:" o; do
  case "$o" in
    d) DEVICE="${OPTARG}" ;;
    e) ETHERNET_DEVICE="${OPTARG}" ;;
    s) SSID_NAME="${OPTARG}" ;;
    p) SSID_PASSWORD="${OPTARG}" ;;
    u) FILE_URL="${OPTARG}" ;;
    c) FILE_CHECKSUM="${OPTARG}" ;;
    t) TIME_DELAY="${OPTARG}" ;;
    n) NAMESERVER="${OPTARG}" ;;
    *) usage ;;
  esac
done

if [ -z "${SSID_NAME}" ] || [ -z "${SSID_PASSWORD}" ]; then
    usage
fi

# test WLAN device connection
test_wlan_connection() {
    info_msg "Running wlan connect test..."
    echo "ctrl_interface=/var/run/wpa_supplicant" > /tmp/wpa.conf
    echo "update_config=1" >> /tmp/wpa.conf
    wpa_passphrase "${SSID_NAME}" "${SSID_PASSWORD}" >> /tmp/wpa.conf
    wpa_supplicant -dd -Dnl80211 -P /tmp/wpa_supplicant.pid -i "${DEVICE}" -c /tmp/wpa.conf -B
    dhclient -pf /tmp/dhclient.pid "${DEVICE}"
    check_return "wlan-connect"
    has_address=$(ip -f inet addr show "${DEVICE}")
    if [ -z "${has_address}" ]; then
        report_fail "wlan-ip-address"
        kill -9 "$(cat /tmp/wpa_supplicant.pid)"
        kill -9 "$(cat /tmp/dhclient.pid)"
        exit 1
    fi
    echo "IP Address:"
    echo "${has_address}"
    report_pass "wlan-ip-address"
    echo "IP Route:"
    ip route

    if [ -n "${NAMESERVER}" ]; then
        mv /etc/resolv.conf /etc/resolv.conf.backup
        echo "nameserver ${NAMESERVER}" > /etc/resolv.conf
    fi
}

# test WLAN download
test_wlan_download() {
    info_msg "Running wlan download test..."
    ping -c 4 www.google.com
    check_return "wlan-ping"
    curl -OL --interface "${DEVICE}" "${FILE_URL}"
    check_return "wlan-download"
    local_file="$(basename "${FILE_URL}")"
    local_md5="$(md5sum "$(basename "${local_file}")" | awk '{print $1}')"
    echo "local_md5=${local_md5}"
    test "${local_md5}" = "${FILE_CHECKSUM}"
    check_return "wlan-download-checksum"
    rm -f "${local_file}"
}

# Test run.
! check_root && error_msg "This script must be run as root"
create_out_dir "${OUTPUT}"

info_msg "About to run wlan download test..."
info_msg "Output directory: ${OUTPUT}"

if [ -n "${ETHERNET_DEVICE}" ]; then
    ip link set "${ETHERNET_DEVICE}" down
    check_return "eth-down"
fi

systemctl stop wpa_supplicant # to don't interfere with our wpa_supplicant instance
ip link set "${DEVICE}" up
sleep "${TIME_DELAY}" # XXX: some devices needs a wait after up to be ready, default: 0s
iw dev "${DEVICE}" scan
exit_on_fail "wlan-scan"
test_wlan_connection
if [ -n "${FILE_URL}" ]; then
    test_wlan_download
fi

wpa_cli remove_network 0
check_return "wlan-disconnect"
ip link set "${DEVICE}" down
kill -9 "$(cat /tmp/wpa_supplicant.pid)"
kill -9 "$(cat /tmp/dhclient.pid)"

if [ -n "${NAMESERVER}" ]; then
    mv /etc/resolv.conf.backup /etc/resolv.conf
fi

if [ -n "${ETHERNET_DEVICE}" ]; then
    ip link set "${ETHERNET_DEVICE}" up
    check_return "eth-up"
fi
