#!/bin/bash
#
# ui browser tests by using Robot framework
#
# Copyright (C) 2016 Linaro Limited
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
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/ui-browser-test-results.txt"
UI_BROWSER_TEST_OUTPUT="ui-browser-test-output"

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
    u) TESTUSER="${OPTARG}" && id "${TESTUSER}" ;;
    *) usage ;;
  esac
done

if [  $# -ne 4 ]; then
    usage
fi


# Test run.
! check_root && error_msg "This script must be run as root"
pkgs="python2.7 python-pip python-lxml"
install_deps "${pkgs}" "${SKIP_INSTALL}"

create_out_dir "${OUTPUT}"

"${WD}"/install.sh

(
  # Copy robot test scripts to /tmp
  cp -a robot-test-scripts /tmp/ || error_msg "Could not copy scripts to /tmp"
  # Tests should runs by linaro users because X owned by linaro user.
  # linaro user can not create output files in /root
  # so change directory to /tmp
  cd /tmp || error_msg "Could not cd into /tmp"
  # Run as TESTUSER
  su "${TESTUSER}" -c "${WD}"/run-robot-tests.sh
  # "${UI_BROWSER_TEST_OUTPUT}" directory created by TESTUSER from run-robot-tests.sh
  mv "${UI_BROWSER_TEST_OUTPUT}" "${OUTPUT}"
  mv robot-test-scripts "${OUTPUT}"
  # Parse test results
  python "${WD}"/robot-results-parser.py "${OUTPUT}"/"${UI_BROWSER_TEST_OUTPUT}"/output.xml >> "${RESULT_FILE}"
)
