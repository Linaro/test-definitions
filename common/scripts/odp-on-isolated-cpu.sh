#!/bin/bash
#
# Author: Santosh Shukla <santosh.shukla@linaro.org>
#
# This script uses is-cpu-isolated.sh script (superset script) to isolate
# a cpu or set of cpus (comma separated cpus list passed as argument $1 to
# this script, Migrate possible kernel background tasks to boot cpu)
#
# We record odp app isolation time using is-cpu-isolated.sh script's "duration" argument.
#
# SCRIPT ARGUMENTS
# $1: Comma separated list of CPUs to isolate
# $2: Full odp command format like below
#
# "odp_l2fwd -i 0,2 -m 0 -c 2"
# "odp_isolation -l 1,2"
#
# cut-n-paste below example to test the script :
# ./odp-on-isolated-cpu.sh 1,2 "odp_l2fwd -i 0,2 -m 0 -c 2" &
# ./odp-on-isolated-cpu.sh
#
# NOTE: it is assumed that odp bin copied to filesystem location /usr/local/bin
#

# Script arguments
ISOL_CPUS="1,2"		# CPU to isolate, default 1,2. Comma-separated list of CPUs.
ODP_CMD="odp_isolation -l 1,2"	# Default odp cmd to run

# get number of isol cpus
get_cpu_count() {

	cpu_count=0
	for i in `echo $ISOL_CPUS | sed 's/,/ /g'`; do
		let cpu_count++
	done

	echo $cpu_count
}

# Create odp setup for isolation
odp_isol_setup() {
	# Get actual odp binary name out from $ODP_CMD
	ODP_APP=`echo $ODP_CMD | cut -d " " -f1`

	# Isolate cpu
	$(pwd)/is-cpu-isolated.sh -q -c $ISOL_CPUS -t $ODP_APP -f "isolate"

	# Run odp application
	$ODP_CMD &

	# Get odp main() process pid
	proc_pid=$!

	# Few big application initialization takes more time to launch DP threads,
	# In that duration NO thread pid entry found in /proc/$proc_pid/tasks.
	# So better wait till application launches all the possible threads
	# and its pid reflected in /proc/$proc_pid/tasks.
	# for example : dpdk-l2fwd takes more time to launch thread.
	while :
	do
		# loop until all thread pid found in /proc/$proc_pid/task
		if [ $(ls /proc/$proc_pid/task | wc -l) -gt $(get_cpu_count) ];
		then
			break
		fi
	done

	# Echo odp main() process pid
	echo "ODP process id: $proc_pid"

	# List odp threads pid in variable thd_pid_list
	thd_pid_list=$(ls /proc/$proc_pid/task | grep -v $proc_pid)

	# Print thread pid list
	echo "ODP threads: $thd_pid_list"

	# Fill odp threads pid into arr[]
	k=0
	for i in $thd_pid_list; do
		arr[k]=$i;
		let k++
	done

	k=0
	for i in `echo $ISOL_CPUS | sed 's/,/ /g'`; do
		# Move thread to isolated CPU
		echo ${arr[$k]} > /dev/cpuset/dplane/cpu$i/tasks
		let k++
	done

	echo "DP Application isolation duration"
	$(pwd)/is-cpu-isolated.sh -q -c $ISOL_CPUS -t $ODP_APP -f "duration"

	echo "DP Application clear isol cpuset"
	$(pwd)/is-cpu-isolated.sh -q -c $ISOL_CPUS -t $ODP_APP -f "clear"
}

## Check validity of arguments
USAGE="Usage: $0 <CPUs to isolate (default 1,2), comma separated list> <odp_* binary full command in double quote (default odp_isolation)>"

if [ "$1" = "-h" -o "$1" = "--help" ]; then
	echo "$USAGE"
	exit 0
fi

# Parse argument
[ "$1" ] && ISOL_CPUS=$1
[ "$2" ] && ODP_CMD=$2

# Create odp setup for isolation
odp_isol_setup
