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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA
#
# Contributors:
#     Amit Daniel <amit.kachhap@linaro.org> (Samsung Electronics)
#       - initial API and implementation
#

# URL : https://wiki.linaro.org/WorkingGroups/PowerManagement/Doc/QA/Scripts#thermal_05

source ../include/functions.sh
source ../include/thermal_functions.sh

verify_cpufreq_cooling_device_action() {
    local dirpath=$THERMAL_PATH/$1
    local cdev_name=$1
    shift 1

    local cpufreq_cdev=$(cat $dirpath/type)
    cat $dirpath/type | grep cpufreq
    if [ $? -ne 0  ] ; then
	return 0
    fi

    local max_state=$(cat $dirpath/max_state)
    local prev_state_val=$(cat $dirpath/cur_state)
    disable_all_thermal_zones

    local count=1
    local before_scale_max=0
    local after_scale_max=0
    local change=0

    while (test $count -le $max_state); do
	echo 0 > $dirpath/cur_state
	sleep 1

	store_scaling_maxfreq
	before_scale_max=$scale_freq

	echo $count > $dirpath/cur_state
	sleep 1

	store_scaling_maxfreq
	after_scale_max=$scale_freq

	check_scaling_freq $before_scale_max $after_scale_max
	change=$?

	check "cdev=$cdev_name state=$count" "test $change -ne 0"

	count=$((count+1))
    done
    enable_all_thermal_zones
    echo $prev_state_val > $dirpath/cur_state
}
for_each_cooling_device verify_cpufreq_cooling_device_action
test_status_show
