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

# URL : https://wiki.linaro.org/WorkingGroups/PowerManagement/Doc/QA/Scripts#cpuidle_01

source ../include/functions.sh

STATES="desc latency name power time usage"
FILES="current_driver current_governor_ro"

check_cpuidle_state_files() {

    local dirpath=$CPU_PATH/$1/cpuidle
    shift 1

    for i in $(ls -d $dirpath/state*); do
	for j in $STATES; do
	    check_file $j $i || return 1
	done
    done

    return 0
}

check_cpuidle_files() {

    local dirpath=$CPU_PATH/cpuidle

    for i in $FILES; do
	check_file $i $CPU_PATH/cpuidle || return 1
    done

    return 0
}

check_cpuidle_files

for_each_cpu check_cpuidle_state_files
test_status_show
