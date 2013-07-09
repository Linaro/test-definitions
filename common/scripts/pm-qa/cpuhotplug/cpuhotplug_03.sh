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

# URL : https://wiki.linaro.org/WorkingGroups/PowerManagement/Doc/QA/Scripts#cpuhotplug_03

source ../include/functions.sh

check_affinity_fails() {
    local cpu=$1
    local cpuid=${cpu:3}
    local dirpath=$CPU_PATH/$1
    local ret=

    if [ "$cpu" == "cpu0" ]; then
	return 0
    fi

    set_offline $cpu

    taskset -c $cpuid /bin/true
    ret=$?
    check "setting affinity on cpu fails" "test $ret -ne 0"

    set_online $cpu

    return 0
}

for_each_cpu check_affinity_fails
test_status_show
