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

# URL : https://wiki.linaro.org/WorkingGroups/PowerManagement/Doc/QA/Scripts#cpufreq_07

source ../include/functions.sh

CPUBURN=../utils/cpuburn

check_ondemand() {

    local cpu=$1
    local maxfreq=$(get_max_frequency $cpu)
    local minfreq=$(get_min_frequency $cpu)
    local curfreq=$(get_frequency $cpu)
    local pid=

    set_governor $cpu ondemand

    # wait for a quescient point
    for i in $(seq 1 10); do

	if [ "$minfreq" == "$(get_frequency $cpu)" ]; then

	    $CPUBURN $cpu &
	    pid=$!

	    sleep 1
	    wait_latency $cpu
	    curfreq=$(get_frequency $cpu)
	    kill $pid

	    check "'ondemand' increase frequency on load" "test \"$curfreq\" == \"$maxfreq\""
	    if [ "$?" != "0" ]; then
		return 1
	    fi

	    sleep 1
	    curfreq=$(get_frequency $cpu)

	    check "'ondemand' decrease frequency on idle" "test \"$curfreq\" == \"$minfreq\""
	    if [ "$?" != "0" ]; then
		return 1
	    fi

	    return 0
	fi

	sleep 1

    done

    log_skip "can not reach a quescient point for 'ondemand'"

    return 1
}

if [ $(id -u) != 0 ]; then
    log_skip "run as non-root"
    exit 0
fi

supported=$(cat $CPU_PATH/cpu0/cpufreq/scaling_available_governors | grep "ondemand")
if [ -z "$supported" ]; then
    log_skip "ondemand not supported"
    exit 0
fi

save_governors

trap "restore_governors; sigtrap" SIGHUP SIGINT SIGTERM

for_each_cpu check_ondemand

restore_governors
test_status_show
