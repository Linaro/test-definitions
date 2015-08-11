#!/bin/sh

# Variables for loop, counter, cpu's
BUSYLOOP=$1
COUNTER=$2
CPU=$3

# Check for binaries availability
if [ ! -f "/usr/local/bin/perf_ev_open" ] || [ ! -f "/usr/local/bin/perf_rc_mmap" ]; then
    echo "Error! the command 'perf tests' doesn't exist!"
    lava-test-case perf-mmaptest --result fail
    exit 1
fi

log_file="perfmmap.log";
# Run tests on each cpu
for cnt in ${COUNTER};
do
    for i in ${CPU};
    do
	echo "On cpu $i" >> ${log_file};
        taskset -c $i perf_ev_open -n${BUSYLOOP} -c${cnt} >> ${log_file};
        taskset -c $i perf_rc_mmap -n${BUSYLOOP} -c${cnt} >> ${log_file};
    done;
done;

cat ${log_file};

#Parsing file for result
lava-test-run-attach ${log_file};
Max=1500000
Avg=1500
tmp=0
tmp_max=0
while read l;
do
	avg=$(echo ${l}|grep -o "avg delay\[cpucycles\]=[0-9]*"  | grep -o "[0-9]*")
	max=$(echo ${l}|grep -o "max delay\[cpucycles\]=[0-9]*"  | grep -o "[0-9]*")
	if [ ${avg} ] && [ ${avg} -gt ${tmp} ]; then
		tmp=${avg}
	fi
	if [ ${max} ] && [ ${max} -gt ${tmp_max} ]; then
		tmp_max=${max}
	fi
done < ${log_file}
if [ ${tmp} -gt 0 ]; then
	if [ ${Avg} -gt ${tmp} ]; then
		lava-test-case perfmmap-Avg --result pass --units cpucycles --measurement ${tmp}
	else
		lava-test-case perfmmap-Avg --result fail --units cpucycles --measurement ${tmp}
	fi
fi
if [ ${tmp_max} -gt 0 ]; then
	if [ ${Max} -gt ${tmp_max} ]; then
		lava-test-case perfmmap-Max --result pass --units cpucycles --measurement ${tmp_max}
	else
		lava-test-case perfmmap-Max --result fail --units cpucycles --measurement ${tmp_max}
	fi
fi
