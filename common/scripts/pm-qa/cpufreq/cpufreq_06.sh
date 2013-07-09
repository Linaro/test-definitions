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

# URL : https://wiki.linaro.org/WorkingGroups/PowerManagement/Doc/QA/Scripts#cpufreq_06

source ../include/functions.sh

CPUCYCLE=../utils/cpucycle

compute_freq_ratio() {

    local cpu=$1
    local freq=$2

    set_frequency $cpu $freq

    result=$($CPUCYCLE $cpu)
    if [ $? != 0 ]; then
	return 1
    fi

    results[$index]=$(echo "scale=3;($result / $freq)" | bc -l)
    index=$((index + 1))
}

compute_freq_ratio_sum() {

    res=${results[$index]}
    sum=$(echo "($sum + $res)" | bc -l)
    index=$((index + 1))

}

__check_freq_deviation() {

    res=${results[$index]}

    # compute deviation
    dev=$(echo "scale=3;((( $res - $avg ) / $avg) * 100 )" | bc -l)

    # change to absolute
    dev=$(echo $dev | awk '{ print ($1 >= 0) ? $1 : 0 - $1}')

    index=$((index + 1))

    res=$(echo "($dev > 5.0)" | bc -l)
    if [ "$res" = "1" ]; then
	return 1
    fi

    return 0
}

check_freq_deviation() {

    local cpu=$1
    local freq=$2

    check "deviation for frequency $(frequnit $freq)" __check_freq_deviation

}

check_deviation() {

    local cpu=$1

    set_governor $cpu userspace

    for_each_frequency $cpu compute_freq_ratio

    index=0
    sum=0

    for_each_frequency $cpu compute_freq_ratio_sum

    avg=$(echo "scale=3;($sum / $index)" | bc -l)

    index=0
    for_each_frequency $cpu check_freq_deviation
}

if [ $(id -u) != 0 ]; then
    log_skip "run as non-root"
    exit 0
fi

supported=$(cat $CPU_PATH/cpu0/cpufreq/scaling_available_governors | grep "userspace")
if [ -z "$supported" ]; then
    log_skip "userspace not supported"
    exit 0
fi

save_governors
save_frequencies

trap "restore_frequencies; restore_governors; sigtrap" SIGHUP SIGINT SIGTERM

for_each_cpu check_deviation

restore_frequencies
restore_governors
test_status_show
