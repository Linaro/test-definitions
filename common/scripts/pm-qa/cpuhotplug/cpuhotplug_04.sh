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

# URL : https://wiki.linaro.org/WorkingGroups/PowerManagement/Doc/QA/Scripts#cpuhotplug_04

CPUBURN=../utils/cpuburn
source ../include/functions.sh

check_task_migrate() {
    local cpu=$1
    local cpuid=${cpu:3}
    local cpumask=$((1 << cpuid))
    local dirpath=$CPU_PATH/$1
    local pid=
    local ret=

    if [ "$cpu" == "cpu0" ]; then
	return 0
    fi

    taskset -c 0x$cpumask $CPUBURN $cpu &
    pid=$!
    sleep 1 # let taskset to do setaffinity before checking

    ret=$(taskset -p $pid | cut -d ':' -f 2)
    ret=$(echo $ret) # remove trailing whitespace
    ret=$(printf "%d" 0x$ret)
    check "affinity is set" "test $cpumask -eq $ret"

    sleep 1
    set_offline $cpu
    ret=$?

    check "offlining a cpu with affinity succeed" "test $ret -eq 0"

    ret=$(taskset -p $pid | cut -d ':' -f 2)
    ret=$(echo $ret)
    ret=$(printf "%d" 0x$ret)
    check "affinity changed" "test $cpumask -ne $ret"

    kill $pid

    # in any case we set the cpu online in case of the test fails
    set_online $cpu

    return 0
}

for_each_cpu check_task_migrate
test_status_show
