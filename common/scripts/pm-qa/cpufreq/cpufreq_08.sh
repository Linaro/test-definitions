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

# URL : https://wiki.linaro.org/WorkingGroups/PowerManagement/Doc/QA/Scripts#cpufreq_08

source ../include/functions.sh

CPUBURN=../utils/cpuburn

check_frequency() {
    local cpu=$1
    local freq=$2
    local curfreq=
    local pid=

    $CPUBURN $cpu &
    pid=$!

    set_frequency $cpu $freq

    wait_latency $cpu
    curfreq=$(get_frequency $cpu)
    kill $pid

    check "'userspace' $(frequnit $freq) is fixed" "test \"$curfreq\" == \"$freq\""
    if [ "$?" != "0" ]; then
	return 1
    fi

    return 0
}

check_userspace() {

    local cpu=$1
    local maxfreq=$(get_max_frequency $cpu)
    local minfreq=$(get_min_frequency $cpu)
    local curfreq=$(get_frequency $cpu)

    set_governor $cpu userspace

    for_each_frequency $cpu check_frequency $minfreq
}

save_governors

if [ $(id -u) != 0 ]; then
    log_skip "run as non-root"
    exit 0
fi

supported=$(cat $CPU_PATH/cpu0/cpufreq/scaling_available_governors | grep "userspace")
if [ -z "$supported" ]; then
    log_skip "userspace not supported"
    exit 0
fi

trap "restore_governors; sigtrap" SIGHUP SIGINT SIGTERM

for_each_cpu check_userspace

restore_governors
test_status_show
