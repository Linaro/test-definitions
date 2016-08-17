#!/bin/sh
#
# Run ui browser tests by using Robot framework
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

. ./common/scripts/include/sh-test-lib
LANG=C
export LANG
WD="$(pwd)"
RESULT_FILE="${WD}/results.txt"

usage()
{
    echo "usage:"
    echo "    $0 $1 (username)"
    echo "ex: $0 linaro"
}

if [  $# -ne 1 ]; then
    echo "param missing!"
    usage
    exit 1
fi

# Default user is linaro
TESTUSER=$1

pkgs="git python2.7 python-pip python-lxml"
install_deps "${pkgs}"

[ -f "${RESULT_FILE}" ] && \
mv "${RESULT_FILE}" "${RESULT_FILE}_$(date +%Y%m%d%H%M%S)"
echo

# Tests should runs by linaro users because X owned by linaro user.
# linaro user can not create output files in /root
# so change directory to /tmp
cd /tmp
git clone http://git.linaro.org/qa/robot-framework-tests.git --depth=1
./robot-framework-tests/install-on-debian.sh
su ${TESTUSER} -c ./robot-framework-tests/run-robot-tests.sh
python ./robot-framework-tests/robot-results-parser.py output.xml >> ${RESULT_FILE}
cd -
