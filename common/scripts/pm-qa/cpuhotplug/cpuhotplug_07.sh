#!/bin/bash
#
# PM-QA validation test suite for the power management on Linux
#
# Copyright (C) 2011, Linaro Limited.
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
#     Daniel Lezcano <daniel.lezcano@linaro.org> (IBM Corporation)
#       - initial API and implementation
#

# URL : https://wiki.linaro.org/WorkingGroups/PowerManagement/Doc/QA/Scripts#cpuhotplug_07

source ../include/functions.sh
TMPFILE=cpuhotplug_07.tmp

check_notification() {
    local cpu=$1
    local cpuid=${cpu:3}
    local pid=
    local ret=

    if [ "$cpu" == "cpu0" ]; then
	return 0
    fi

    # damn ! udevadm is buffering the output, we have to use a temp file
    # to retrieve the output
    rm -f $TMPFILE
    udevadm monitor --kernel --subsystem-match=cpu > $TMPFILE &
    pid=$!

    set_offline $cpu
    set_online $cpu

    # let the time the notification to reach userspace
    # and buffered in the file
    sleep 1
    kill $pid

    grep "offline" $TMPFILE | grep -q "/devices/system/cpu/$cpu"
    ret=$?
    check "offline event was received" "test $ret -eq 0"

    grep "online" $TMPFILE | grep -q "/devices/system/cpu/$cpu"
    ret=$?
    check "online event was received" "test $ret -eq 0"

    rm -f $TMPFILE
}

for_each_cpu check_notification
test_status_show
