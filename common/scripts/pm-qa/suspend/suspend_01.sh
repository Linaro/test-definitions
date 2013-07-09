#!/bin/bash
#
# PM-QA validation test suite for the power management on Linux
#
# Copyright (C) 2012, Linaro Limited.
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
# Contributors:
#     Hongbo ZHANG <hongbo.zhang@linaro.org> (ST-Ericsson Corporation)
#       - initial API and implementation
#

# URL : https://wiki.linaro.org/WorkingGroups/PowerManagement/Doc/QA/Scripts#suspend_01


source ../include/functions.sh
source ../include/suspend_functions.sh

if [ "$suspend_dbus" -eq 0 ]; then
	log_skip "dbus message suspend test not enabled"
	exit 0
fi

if [ -x /usr/bin/dbus-send ]; then
	phase
	check "suspend by dbus message" suspend_system "dbus"
	if [ $? -ne 0 ]; then
		cat "$LOGFILE" 1>&2
	fi
else
	log_skip "dbus-send command not exist"
fi

restore_trace
test_status_show
rm -f "$LOGFILE"
