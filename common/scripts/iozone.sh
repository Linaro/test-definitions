#!/bin/sh

TEST_ITEM="write rewrite read reread random_read random_write bkwd_read record_rewrite stride_read fwrite frewrite fread freread"
while read in
do
    n=1
    kb=`echo ${in} | cut -d' ' -f 1`
    reclen=`echo ${in} | cut -d' ' -f 2`
    for i in `echo ${in} | cut -d' ' -f 3-`
    do
        itm=`echo ${TEST_ITEM} | cut -d' ' -f ${n}`
        echo "${itm}-${kb}-KB-${reclen}-reclen: ${i} pass"
        n=$(($n+1))
    done
done

