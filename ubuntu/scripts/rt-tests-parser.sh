#!/bin/sh

LOG=$1

N=`grep -n "^#1 -> #0" ${LOG} | tail -n1 | cut -d':' -f1`
sed -n "${N},$ p" ${LOG} > tmp.log

while read l
do
    TC="`echo ${l} | cut -d',' -f1`"
    R="`echo ${l} | cut -d',' -f2-`"
    IFS=','
    for c in ${R}
    do
        c="`echo $c|sed 's/^[ ]*//'`"
        t="`echo ${c} | cut -d' ' -f1`"
        v="`echo ${c} | cut -d' ' -f2`"
        echo "${TC} (${t}): ${v} usec pass"
    done
    unset IFS
done < tmp.log
