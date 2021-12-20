#!/bin/sh
#
# systemd-timesyncd test
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
SKIP_INSTALL="true"
NTP_SERVER="pool.ntp.org"

usage() {
    echo "Usage: $0 [-n ntpserver] [-s <true|false>]" 1>&2
    exit 1
}

while getopts "s:n:h" o; do
    case "$o" in
        n) NTP_SERVER="${OPTARG}" ;;
        s) SKIP_INSTALL="${OPTARG}" ;;
        h|*) usage ;;
    esac
done

! check_root && error_msg "You need to be root to run this script."

if [ "$SKIP_INSTALL" = 'true' ] || [ "$SKIP_INSTALL" = 'True' ]; then
    warn_msg "Dependencies for timesyncd test installation skipped!"
else
    install_deps "python3-pip"
fi

# Test run.
create_out_dir "${OUTPUT}"

timedatectl show -p CanNTP --value | grep "yes"
check_return "timesyncd-canntp"
timedatectl show -p NTP --value | grep "yes"
check_return "timesyncd-ntp"
timedatectl show -p NTPSynchronized --value | grep "yes"
check_return "timesyncd-ntpsynchronized"

# check if local time is the same a served by NTP
# ignore failure in package installation
# should this happen the script will fail gracefully
python3 -m pip install --user ntplib || true
python3 timesynctest.py -n "${NTP_SERVER}"
check_return "timesyncd-systemtime"
