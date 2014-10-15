#!/bin/sh

TIMES=$1
INTERVAL=$2
LATENCY=$3
DURATION=$4

if [ ! -f "/usr/bin/cyclictest" ]; then
    echo "Error! the command 'cyclictest' doesn't exist!"
    lava-test-case cyclictest-basic --result fail
    exit 1
fi

for t in $(seq 1 ${TIMES});
do
    threads=$(($t * 2));
    log_file="${threads}-cyc.log";
    echo "Running \"cyclictest -q -t ${threads} -i ${INTERVAL} --latency=${LATENCY} -D ${DURATION}\"" | tee ${log_file};
    for i in $(seq 0 5);
    do
        cyclictest -q -t ${threads} -i ${INTERVAL} --latency=${LATENCY} -D ${DURATION} | tee result.log;
        cat result.log >> ${log_file};
    done;
    lava-test-run-attach ${log_file};
    Max=0
    Min=0
    Avg=0
    n=0
    while read l;
    do
        max=$(echo ${l}|grep -o "Max:[[:space:]]*[0-9]*"|grep -o "[0-9]*")
        min=$(echo ${l}|grep -o "Min:[[:space:]]*[0-9]*"|grep -o "[0-9]*")
        avg=$(echo ${l}|grep -o "Avg:[[:space:]]*[0-9]*"|grep -o "[0-9]*")
        if [ ${max} -a ${min} -a ${avg} ]; then
            [ ${max} -gt ${Max} ] && Max=${max}
            [ ${Min} -eq 0 -o ${min} -lt ${Min} ] && Min=${min}
            Avg=$((${Avg}+${avg}))
            n=$((${n}+1))
        fi
    done < ${log_file}
    Avg=$((${Avg}/${n}))
    lava-test-case ${threads}-threads-Max --result pass --units us --measurement ${Max}
    lava-test-case ${threads}-threads-Min --result pass --units us --measurement ${Min}
    lava-test-case ${threads}-threads-Avg --result pass --units us --measurement ${Avg}
done
