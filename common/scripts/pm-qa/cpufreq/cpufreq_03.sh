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

# URL : https://wiki.linaro.org/WorkingGroups/PowerManagement/Doc/QA/Scripts#cpufreq_03

source ../include/functions.sh

check_governor() {

    local cpu=$1
    local newgov=$2

    shift 2

    local oldgov=$(get_governor $cpu)

    set_governor $cpu $newgov

    check "governor change to '$newgov'" "test \"$(get_governor $cpu)\" == \"$newgov\""

    set_governor $cpu $oldgov
}

if [ $(id -u) != 0 ]; then
    log_skip "run as non-root"
    exit 0
fi

for_each_cpu for_each_governor check_governor || exit 1
test_status_show
