#!/bin/sh

LOG=$1
TEST_ID="format_version,bonnie_version,name,concurrency,seed,file_size,io_chunk_size,putc,putc_cpu,put_block,put_block_cpu,rewrite,rewrite_cpu,getc,getc_cpu,get_block,get_block_cpu,seeks,seeks_cpu,num_files,max_size,min_size,num_dirs,file_chunk_size,seq_create,seq_create_cpu,seq_stat,seq_stat_cpu,seq_del,seq_del_cpu,ran_create,ran_create_cpu,ran_stat,ran_stat_cpu,ran_del,ran_del_cpu,putc_latency,put_block_latency,rewrite_latency,getc_latency,get_block_latency,seeks_latency,seq_create_latency,seq_stat_latency,seq_del_latency,ran_create_latency,ran_stat_latency,ran_del_latency"
TEST_RESULT=`cat ${LOG} | grep "^[0-9]"`

for i in `seq 8 48`
do
    unset unit
    t=`echo ${TEST_ID}|cut -d, -f$i`
    r=`echo ${TEST_RESULT}|cut -d, -f$i`
    [ -z "${r}" -o "${t}" = "num_files" ] && continue
    t_suffix=${t##*_}
    unit=`echo ${r}|sed 's/[0-9+]*//'`
    [ "${t_suffix}" = "cpu" ] && unit="%CPU"
    if [ -z "${unit}" -a -z "`echo ${r} | grep -o [\+]*`" ]; then
        [ ${i} -gt 17 ] && unit="/sec" || unit="K/sec"
    fi
    unset UNIT_OPT
    [ -n "${unit}" ] && UNIT_OPT="--units ${unit}"
    lava-test-case ${t} --result pass --measurement ${r%%[a-z]*} ${UNIT_OPT}
done
