#!/bin/bash

# Variable decided outcome of test, this is the minimum isolation we need.
MIN_ISOLATION=10
RESULT="PASS"

if [ $2 ]; then
	MIN_ISOLATION=$2
fi

# $1 is the number of samples required of isolation time, by default 1
if [ "$1" = "-h" -o "$1" = "--help" ]; then
	echo "Usage: $0 <number of samples to take> <Min Isolation Time Expected>"
	exit
elif [ $1 ]; then
	sample_count=$1
else
	sample_count=1
fi


# ROUTINES
debug_script=1
isdebug() {
	if [ $debug_script -eq 1 ]; then
		$*
	fi
}

# routine to get tick count
get_tick_count() { cat /proc/interrupts | grep arch_timer | grep 30 | sed 's/\s\+/ /g' | cut -d' ' -f4 ; }
#For testing script on: x86
#get_tick_count() { cat /proc/interrupts | grep NMI | sed 's/\s\+/ /g' | cut -d' ' -f4 ; }

# routine to get CPU isolation time
get_isolation_duration() {
	isdebug echo ""
	isdebug echo ""
	isdebug echo "Capture Isolation time"
	isdebug echo "----------------------"

	isdebug echo "No. of samples requested:" $sample_count", min isolation required:" $MIN_ISOLATION
	isdebug echo ""

	new_count=$(get_tick_count)
	isdebug echo "initial count: " $new_count

	old_count=$new_count
	while [ $new_count -eq $old_count ]
	do
		new_count=$(get_tick_count)
	done

	isdebug echo "count locked: " $new_count

	# Get time as a UNIX timestamp (seconds elapsed since Jan 1, 1970 0:00 UTC)
	T2="$(date +%s)"

	x=0
	while [ $x -lt $sample_count ]
	do
		let x=x+1

		T1=$T2
		isdebug echo "Start Time in seconds: ${T1}"

		# sometimes there are continuous ticks, skip them by sleeping for 100 ms.
		sleep .1

		# get count again after continuous ticks are skiped
		old_count=$(get_tick_count)
		new_count=$old_count


		while [ $new_count -eq $old_count ]
		do
			new_count=$(get_tick_count)
		done

		isdebug echo "sampling over: " $new_count

		T2="$(date +%s)"
		isdebug echo "End Time in seconds: ${T2}"

		T=$(($T2-$T1))
		isdebug echo "Time in seconds: "
		echo $T
		isdebug echo ""

		if [ $T -lt $MIN_ISOLATION -a $RESULT="PASS"  ]; then
			RESULT="FAIL"
		fi
	done

	isdebug echo "Result:"
	echo $RESULT": min-isolation "$MIN_ISOLATION "seconds"
	isdebug echo ""
}

isolate_cpu1() {
	isdebug echo ""
	isdebug echo "Started Isolating CPUs - via CPUSETS"
	isdebug echo "------------------------------------"
	isdebug echo ""

	# Check that we have cpusets enabled in the kernel
	if ! grep -q -s cpuset /proc/filesystems ; then
		echo "Error: Kernel is lacking support for cpuset!"
		exit 1
	fi

	# Try to disable sched_tick_max_deferment
	if [ -d /sys/kernel/debug -a -f /sys/kernel/debug/sched_tick_max_deferment ]; then
		echo -1 > /sys/kernel/debug/sched_tick_max_deferment
		echo "sched_tick_max_deferment set to:" `cat /sys/kernel/debug/sched_tick_max_deferment`
	else
		sysctl -e kernel.sched_tick_max_deferment=-1

	fi

	# make sure that the /dev/cpuset dir exits
	# and mount the cpuset filesystem if needed
	[ -d /dev/cpuset ] || mkdir /dev/cpuset
	mount | grep /dev/cpuset > /dev/null || mount -t cpuset none /dev/cpuset

	# Create 2 cpusets. One GP and one NOHZ domain.
	[ -d /dev/cpuset/gp ] || mkdir /dev/cpuset/gp
	[ -d /dev/cpuset/rt ] || mkdir /dev/cpuset/rt

	# Setup the GP domain: CPU0
	echo 0 > /dev/cpuset/gp/mems
	echo 0 > /dev/cpuset/gp/cpus

	# Setup the NOHZ domain: CPU1
	echo 0 > /dev/cpuset/rt/mems
	echo 1 > /dev/cpuset/rt/cpus

	# Try to move all processes in top set to the GP set.
	for pid in `cat /dev/cpuset/tasks`; do
		if [ -d /proc/$pid ]; then
			echo $pid > /dev/cpuset/gp/tasks 2>/dev/null
			if [ $? != 0 ]; then
				isdebug echo -n "Cannot move PID $pid: "
				isdebug echo "$(cat /proc/$pid/status | grep ^Name | cut -f2)"
			fi
		fi
	done

	# Disable load balancing on top level (otherwise the child-sets' setting
	# won't take effect.)
	echo 0 > /dev/cpuset/sched_load_balance

	# Enable load balancing withing the GP domain
	echo 1 > /dev/cpuset/gp/sched_load_balance

	# But disallow load balancing within the NOHZ domain
	echo 0 > /dev/cpuset/rt/sched_load_balance

	# Start a single threaded task on CPU1 or RT group
	echo $$ > /dev/cpuset/rt/tasks
	stress -q --cpu 1 --timeout 2000 &
	echo $$ > /dev/cpuset/gp/tasks
}

clear_cpusets() {
	isdebug echo ""
	isdebug echo "Started cleaning CPUSETS"
	isdebug echo "------------------------"
	isdebug echo ""

	#
	# Cleanup
	#

	# kill all instances of stress
	for i in `ps | grep stress | sed 's/^\ *//g' | cut -d' ' -f1`;
	do
		kill -9 $i;
	done

	# Try to move all from GP back to root
	for pid in `cat /dev/cpuset/gp/tasks`; do
		if [ -d /proc/$pid ]; then
			echo $pid > /dev/cpuset/tasks 2>/dev/null
			if [ $? != 0 ]; then
				isdebug echo -n "Cannot move PID $pid: "
				isdebug echo "$(cat /proc/$pid/status | grep ^Name | cut -f2)"
			fi
		fi
	done

	# Remove the CPUsets
	rmdir /dev/cpuset/gp
	rmdir /dev/cpuset/rt
}

# tests to run
isolate_cpu1
get_isolation_duration
clear_cpusets
