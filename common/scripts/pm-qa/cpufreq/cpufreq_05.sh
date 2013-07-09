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

# URL : https://wiki.linaro.org/WorkingGroups/PowerManagement/Doc/QA/Scripts#cpufreq_05

source ../include/functions.sh

if [ $(id -u) != 0 ]; then
    log_skip "run as non-root"
    exit 0
fi

save_governors

trap restore_governors SIGHUP SIGINT SIGTERM

switch_ondemand() {
    local cpu=$1
    set_governor $cpu 'ondemand'
}

switch_conservative() {
    local cpu=$1
    set_governor $cpu 'conservative'
}

switch_userspace() {
    local cpu=$1
    set_governor $cpu 'userspace'
}

supported=$(cat $CPU_PATH/cpu0/cpufreq/scaling_available_governors | grep "ondemand")
if [ -z "$supported" ]; then
    log_skip "ondemand not supported"
else
    for cpu in $(ls $CPU_PATH | grep "cpu[0-9].*"); do
        switch_ondemand $cpu
    done
    check "'ondemand' directory exists" "test -d $CPU_PATH/cpufreq/ondemand"
fi

supported=$(cat $CPU_PATH/cpu0/cpufreq/scaling_available_governors | grep "conservative")
if [ -z "$supported" ]; then
    log_skip "conservative not supported"
else
    for cpu in $(ls $CPU_PATH | grep "cpu[0-9].*"); do
        switch_conservative $cpu
    done
    check "'conservative' directory exists" "test -d $CPU_PATH/cpufreq/conservative"
fi

supported=$(cat $CPU_PATH/cpu0/cpufreq/scaling_available_governors | grep "userspace")
if [ -z "$supported" ]; then
    log_skip "userspace not supported"
else
    for cpu in $(ls $CPU_PATH | grep "cpu[0-9].*"); do
        switch_userspace $cpu
    done

    check "'ondemand' directory is not there" "test ! -d $CPU_PATH/cpufreq/ondemand"
    check "'conservative' directory is not there" "test ! -d $CPU_PATH/cpufreq/conservative"
fi

# if more than one cpu, combine governors
nrcpus=$(ls $CPU_PATH | grep "cpu[0-9].*" | wc -l)
if [ $nrcpus > 1 ]; then
    affected=$(cat $CPU_PATH/cpu0/cpufreq/affected_cpus | grep 1)
    if [ -z $affected ]; then
        switch_ondemand cpu0
        switch_conservative cpu1
        check "'ondemand' directory exists" "test -d $CPU_PATH/cpufreq/ondemand"
        check "'conservative' directory exists" "test -d $CPU_PATH/cpufreq/conservative"
    else
        log_skip "combine governors not supported"
    fi
fi

restore_governors
test_status_show
