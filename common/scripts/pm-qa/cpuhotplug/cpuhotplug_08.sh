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

# URL : https://wiki.linaro.org/WorkingGroups/PowerManagement/Doc/QA/Scripts#cpuhotplug_08

source ../include/functions.sh

function randomize() {
    echo $[ ( $RANDOM % $1 )  + 1 ]
}

random_stress() {
    local cpu_present=$(cat /sys/devices/system/cpu/present | cut -d '-' -f 2)
    local cpurand=$(randomize $cpu_present)
    local ret=

    # randomize will in range "1-$cpu_present) so cpu0 is ignored
    set_offline cpu$cpurand
    ret=$?
    check "cpu$cpurand is offline" "test $ret -eq 0"

    set_online cpu$cpurand
    ret=$?
    check "cpu$cpurand is online" "test $ret -eq 0"
}

for i in $(seq 1 50); do random_stress || break; done
test_status_show
