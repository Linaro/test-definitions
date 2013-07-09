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

source ../Switches.sh

CPU_PATH="/sys/devices/system/cpu"
TEST_NAME=$(basename ${0%.sh})
PREFIX=$TEST_NAME
INC=0
CPU=
pass_count=0
fail_count=0

test_status_show() {
    echo "-------- total = $(($pass_count + $fail_count))"
    echo "-------- pass = $pass_count"
    # report failure only if it is there
    if [ $fail_count -ne 0 ] ; then
      echo "-------- fail = $fail_count"
    fi
}

log_begin() {
    printf "%-76s" "$TEST_NAME.$INC$CPU: $@... "
    INC=$(($INC+1))
}

log_end() {
    printf "$*\n"
}

log_skip() {
    log_begin "$@"
    log_end "skip"
}

for_each_cpu() {

    local func=$1
    shift 1

    cpus=$(ls $CPU_PATH | grep "cpu[0-9].*")

    for cpu in $cpus; do
	INC=0
	CPU=/$cpu
	$func $cpu $@
    done

    return 0
}

for_each_governor() {

    local cpu=$1
    local func=$2
    local dirpath=$CPU_PATH/$cpu/cpufreq
    local governors=$(cat $dirpath/scaling_available_governors)
    shift 2

    for governor in $governors; do
	$func $cpu $governor $@
    done

    return 0
}

for_each_frequency() {

    local cpu=$1
    local func=$2
    local dirpath=$CPU_PATH/$cpu/cpufreq
    local frequencies=$(cat $dirpath/scaling_available_frequencies)
    shift 2

    for frequency in $frequencies; do
	$func $cpu $frequency $@
    done

    return 0
}

set_governor() {

    local cpu=$1
    local dirpath=$CPU_PATH/$cpu/cpufreq/scaling_governor
    local newgov=$2

    echo $newgov > $dirpath
}

get_governor() {

    local cpu=$1
    local dirpath=$CPU_PATH/$cpu/cpufreq/scaling_governor

    cat $dirpath
}

wait_latency() {
    local cpu=$1
    local dirpath=$CPU_PATH/$cpu/cpufreq
    local latency=
    local nrfreq=

    latency=$(cat $dirpath/cpuinfo_transition_latency)
    if [ $? != 0 ]; then
	return 1
    fi

    nrfreq=$(cat $dirpath/scaling_available_frequencies | wc -w)
    if [ $? != 0 ]; then
	return 1
    fi

    nrfreq=$((nrfreq + 1))
    ../utils/nanosleep $(($nrfreq * $latency))
}

frequnit() {
    local freq=$1
    local ghz=$(echo "scale=1;($freq / 1000000)" | bc -l)
    local mhz=$(echo "scale=1;($freq / 1000)" | bc -l)

    res=$(echo "($ghz > 1.0)" | bc -l)
    if [ "$res" = "1" ]; then
	echo $ghz GHz
	return 0
    fi

    res=$(echo "($mhz > 1.0)" | bc -l)
    if [ "$res" = "1" ];then
	echo $mhz MHz
	return 0
    fi

    echo $freq KHz
}

set_frequency() {

    local cpu=$1
    local dirpath=$CPU_PATH/$cpu/cpufreq
    local newfreq=$2
    local setfreqpath=$dirpath/scaling_setspeed

    echo $newfreq > $setfreqpath
    wait_latency $cpu
}

get_frequency() {
    local cpu=$1
    local dirpath=$CPU_PATH/$cpu/cpufreq/scaling_cur_freq
    cat $dirpath
}

get_max_frequency() {
    local cpu=$1
    local dirpath=$CPU_PATH/$cpu/cpufreq/scaling_max_freq
    cat $dirpath
}

get_min_frequency() {
    local cpu=$1
    local dirpath=$CPU_PATH/$cpu/cpufreq/scaling_min_freq
    cat $dirpath
}

set_online() {
    local cpu=$1
    local dirpath=$CPU_PATH/$cpu

    if [ "$cpu" = "cpu0" ]; then
	return 0
    fi

    echo 1 > $dirpath/online
}

set_offline() {
    local cpu=$1
    local dirpath=$CPU_PATH/$cpu

    if [ "$cpu" = "cpu0" ]; then
	return 0
    fi

    echo 0 > $dirpath/online
}

get_online() {
    local cpu=$1
    local dirpath=$CPU_PATH/$cpu

    cat $dirpath/online
}

check() {

    local descr=$1
    local func=$2
    shift 2;

    log_begin "checking $descr"

    $func $@
    if [ $? != 0 ]; then
	log_end "Err"
	fail_count=$(($fail_count + 1))
	return 1
    fi

    log_end "Ok"
    pass_count=$(($pass_count + 1))

    return 0
}

check_file() {
    local file=$1
    local dir=$2

    check "'$file' exists" "test -f" $dir/$file
}

check_cpufreq_files() {

    local dirpath=$CPU_PATH/$1/cpufreq
    shift 1

    for i in $@; do
	check_file $i $dirpath || return 1
    done

    return 0
}

check_sched_mc_files() {

    local dirpath=$CPU_PATH

    for i in $@; do
	check_file $i $dirpath || return 1
    done

    return 0
}

check_topology_files() {

    local dirpath=$CPU_PATH/$1/topology
    shift 1

    for i in $@; do
	check_file $i $dirpath || return 1
    done

    return 0
}

check_cpuhotplug_files() {

    local dirpath=$CPU_PATH/$1
    shift 1

    for i in $@; do
	check_file $i $dirpath || return 1
    done

    return 0
}

save_governors() {

    governors_backup=
    local index=0

    for i in $(ls $CPU_PATH | grep "cpu[0-9].*"); do
	governors_backup[$index]=$(cat $CPU_PATH/$i/cpufreq/scaling_governor)
	index=$((index + 1))
    done
}

restore_governors() {

    local index=0
    local oldgov=

    for i in $(ls $CPU_PATH | grep "cpu[0-9].*"); do
	oldgov=${governors_backup[$index]}
	echo $oldgov > $CPU_PATH/$i/cpufreq/scaling_governor
	index=$((index + 1))
    done
}

save_frequencies() {

    frequencies_backup=
    local index=0
    local cpus=$(ls $CPU_PATH | grep "cpu[0-9].*")
    local cpu=

    for cpu in $cpus; do
	frequencies_backup[$index]=$(cat $CPU_PATH/$cpu/cpufreq/scaling_cur_freq)
	index=$((index + 1))
    done
}

restore_frequencies() {

    local index=0
    local oldfreq=
    local cpus=$(ls $CPU_PATH | grep "cpu[0-9].*")

    for cpu in $cpus; do
	oldfreq=${frequencies_backup[$index]}
	echo $oldfreq > $CPU_PATH/$cpu/cpufreq/scaling_setspeed
	index=$((index + 1))
    done
}

sigtrap() {
    exit 255
}
