#!/bin/sh

# Variables for loop, counter, cpu's
BUSYLOOP=${1}
COUNTER=${2}
CPU=${3}
Max=1500000
Avg=1500
tmp_avg=0
tmp_max=0

# Check for binaries availability
ev_path=$(which perf_ev_open)
mmap_path=$(which perf_rc_mmap)

if [ ! -f "$ev_path" ] || [ ! -f "$mmap_path" ]; then
	echo "Error! the command 'perf tests' doesn't exist!"
	lava-test-case perf-mmaptest --result fail
	exit 1
fi

log_file="perfmmap.log";
# Run tests on each cpu
for cnt in ${COUNTER};
do
	perf_ev_open -n${BUSYLOOP} -c${cnt} >> ${log_file};
	perf_rc_mmap -n${BUSYLOOP} -c${cnt} >> ${log_file};
done;

cat ${log_file};
#function to calculate max
max(){
if [ ${1} ] && [ ${1} -gt ${2} ]; then
	return ${1}
else
	return ${2}
fi
}

#Parsing file for result
lava-test-run-attach ${log_file};
while read line;
do
	avg=$(echo ${line}|grep -o "avg delay\[cpucycles\]=[0-9]*"  | grep -o "[0-9]*")
	max=$(echo ${line}|grep -o "max delay\[cpucycles\]=[0-9]*"  | grep -o "[0-9]*")
	max ${avg} ${tmp_avg}
	tmp_avg="$?"
	if [ ! -z "${max}" ]; then
		max ${max} ${tmp_max}
	fi
	tmp_max="$?"
done < ${log_file}

avg_result="fail"

if [ ${Avg} -gt ${tmp_avg} ]; then
	avg_result="pass"
fi

lava-test-case perfmmap-cpu${CPU}-Avg --result ${avg_result} --units cpucycles --measurement ${tmp_avg}

if [ ${tmp_max} -gt 0 ]; then
	avg_result="fail"
	if [ ${Max} -gt ${tmp_max} ]; then
		avg_result="pass"
	fi
	lava-test-case perfmmap-cpu${CPU}-Max --result ${avg_result} --units cpucycles --measurement ${tmp_max}
fi
rm -f ${log_file};
