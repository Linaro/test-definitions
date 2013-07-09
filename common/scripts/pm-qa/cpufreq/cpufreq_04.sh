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

# URL : https://wiki.linaro.org/WorkingGroups/PowerManagement/Doc/QA/Scripts#cpufreq_04

source ../include/functions.sh

check_frequency() {

    local cpu=$1
    local newfreq=$2

    shift 2

    local oldgov=$(get_governor $cpu)
    local oldfreq=$(get_frequency $cpu)

    set_governor $cpu userspace
    set_frequency $cpu $newfreq

    check "setting frequency '$(frequnit $newfreq)'" "test \"$(get_frequency $cpu)\" == \"$newfreq\""

    set_frequency $cpu $oldfreq
    set_governor $cpu $oldgov
}

if [ $(id -u) != 0 ]; then
    log_skip "run as non-root"
    exit 0
fi

supported=$(cat $CPU_PATH/cpu0/cpufreq/scaling_available_governors | grep "userspace")
if [ -z "$supported" ]; then
    log_skip "userspace not supported"
else
    for_each_cpu for_each_frequency check_frequency || exit 1
fi
test_status_show
