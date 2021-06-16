#!/bin/sh
#
# NetworkManager smoke test
#
# Copyright (C) 2021, Foundries.io
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

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE
IFACE=eth0
SKIP_INSTALL="true"

usage() {
    echo "Usage: $0 [-i interface] [-s <true|false>]" 1>&2
    exit 1
}

while getopts "s:i:h" o; do
    case "$o" in
        i) IFACE="${OPTARG}" ;;
        s) SKIP_INSTALL="${OPTARG}" ;;
        h|*) usage ;;
    esac
done

! check_root && error_msg "You need to be root to run this script."

if [ "$SKIP_INSTALL" = 'true' ] || [ "$SKIP_INSTALL" = 'True' ]; then
    warn_msg "Dependencies for network-manager installation skipped!"
else
    install_deps "network-manager"
fi

# Test run.
create_out_dir "${OUTPUT}"

info_msg "About to run NetworkManager smoke test..."
info_msg "Output directory: ${OUTPUT}"

systemctl status NetworkManager | grep running
check_return "nm-running"

nmcli -c no general status
check_return "nmcli-general-status"

nmcli -c no general hostname
check_return "nmcli-general-hostname"

# check networking status
nmcli -c no networking connectivity | grep full
check_return "nmcli-initial-full-connectivity"

nmcli -c no networking off
check_return "nmcli-networking-off"

nmcli -c no networking connectivity | grep none
check_return "nmcli-none-connectivity"

# it takes a moment to bring networking back up
# make nmcli call blocking for 10 seconds
nmcli -c no -w 10 networking on
check_return "nmcli-networking-on"

# connectivity reporting is delayed despite using blocking call
sleep 10

nmcli -c no networking connectivity | grep full
check_return "nmcli-offon-full-connectivity"

nmcli -c no device show "${IFACE}"
check_return "nmcli-device-show"

nmcli -c no device disconnect "${IFACE}"
check_return "nmcli-device-disconnect"

nmcli -c no networking connectivity | grep none
check_return "nmcli-disconnect-connectivity-none"

# it takes a moment to bring networking back up
# make nmcli call blocking for 10 seconds
nmcli -c no -w 10 device connect "${IFACE}"
check_return "nmcli-device-connect"

nmcli -c no networking connectivity | grep full
check_return "nmcli-device-full-connectivity"
