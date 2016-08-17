#!/bin/bash
#
# ui browser tests by using Robot framework
#
# Copyright (C) 2010 - 2016, Linaro Limited.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# Author: Naresh Kamboju <naresh.kamboju@linaro.org>

set -eu
. ../../lib/sh-test-lib
WD="$(pwd)"
RESULT_FILE="${WD}/ui-browser-test-results.txt"

usage()
{
    echo "Usage: $0 [-u username] [-s <true|false>]" 1>&2
    echo "the user should own X process and DISPLAY=:0"
    exit 1
}


while getopts "s:u:" o; do
  case "$o" in
       # Skip package installation
    s) SKIP_INSTALL="${OPTARG}" ;;
       # Default user is linaro
    u) TESTUSER="${OPTARG}"
       id ${TESTUSER}
       ;;
    *) usage ;;
  esac
done

if [  $# -ne 4 ]; then
    usage
fi


pkgs="python2.7 python-pip python-lxml"
install_deps "${pkgs}" "${SKIP_INSTALL}"

[ -f "${RESULT_FILE}" ] && \
mv "${RESULT_FILE}" "${RESULT_FILE}_$(date +%Y%m%d%H%M%S)"
echo

# Copy robot test scripts to /tmp
cp -a robot-test-scripts /tmp/
# Tests should runs by linaro users because X owned by linaro user.
# linaro user can not create output files in /root
# so change directory to /tmp
cd /tmp
dist_name
if [ "${dist}" = "Debian" ] || [ "${dist}" = "Ubuntu" ]; then
    ${WD}/install-on-debian.sh
else
    echo "Not a debian machine"
fi
# Run as TESTUSER
su ${TESTUSER} -c ${WD}/run-robot-tests.sh
python ${WD}/robot-results-parser.py output.xml >> ${RESULT_FILE}
rm -rf robot-test-scripts
cd -
