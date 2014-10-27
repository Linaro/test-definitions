#!/bin/sh

TIMES=${1-8}
TEST=${2-cpu}
MAX_REQUESTS=${3-50000}
DURATION=${4-20}
FILE_TEST_MODE=${5-seqrewr}

if [ ! `which sysbench` ]; then
    echo "Error! the command 'sysbench' doesn't exist!"
    lava-test-case sysbench --result fail
    exit 1
fi

for i in $(seq 1 ${TIMES});
do
    t=$((${i} * 2));
    log_file="${TEST}-test-${t}-threads.log";
    opt="--test=${TEST} --max-requests=${MAX_REQUESTS} --num-threads=${t} --max-time=${DURATION}"
    [ "${TEST}" = "threadsR" ] && opt="${opt} --thread-locks=$((${t}/2))"
    [ "${TEST}" = "fileio" ] && opt="${opt} --file-test-mode=${FILE_TEST_MODE}"
    echo "Running sysbench ${opt} run" | tee ${log_file};
    sysbench ${opt} run | tee -a ${log_file};
    lava-test-run-attach ${log_file};

    # parse log file & submit to test result
    sed -n -e '/Test execution summary\|General statistics/,/^$/p' ${log_file} | while read line;
    do
        id=$(echo ${line}|awk -F':' '{print $1}')
        val=$(echo ${line}|awk -F':' '{print $2}')
        if [ -n "${val}" ]; then
            u=$(echo ${val}|sed 's/[0-9\.]*//')
            v=$(echo ${val}|sed 's/\([0-9\.]*\)[a-zA-Z]*/\1/')
            # let 's' to be the default unit for time measurement
            [ -n "$(echo ${id}|grep 'time')" ] && [ -z "${u}" ] && u=s
            [ -n "${u}" ] && o="--units ${u} --measurement ${v}" || o="--measurement ${val}"
            lava-test-case "${id}-${t}-threads" --result pass ${o}
        fi
    done
done
