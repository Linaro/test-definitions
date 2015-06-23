#!/bin/sh

LOG=$1

# Find the last line number which starting with control character
N=`grep -n "#0:" ${LOG} | tail -n1 | cut -d':' -f1`
# The rest of lines from #N is the final test result we want
sed -i "s/\x1b\[[0-9]A//" ${LOG}    # Remove the control code
sed -n "${N},$ p" ${LOG} > tmp.log
mv tmp.log ${LOG}

sed "s/.*> //" ${LOG} | sed "s/^#/A/" > tmp.log

grep "CPU" tmp.log > v.log
grep -v "CPU" tmp.log > res.log
while read l;
do
    k="`echo ${l} | cut -d: -f1`"
    v="`echo ${l} | cut -d, -f3|sed 's/^ //'`"
    eval ${k}=${v}
    while read m;
    do
        eval sed -i "s/${k}/\$${k}/" res.log
    done < res.log
done < v.log
while read l
do
    TC="`echo ${l} | cut -d',' -f1`"
    R="`echo ${l} | sed 's/^CPU[0-9]*, //'`"
    IFS=','
    for c in ${R}
    do
        c="`echo $c|sed 's/^[ ]*//'`"
        t="`echo ${c} | cut -d' ' -f1`"
        v="`echo ${c} | cut -d' ' -f2`"
        echo "${TC}_${t}: ${v} usec pass"
    done
    unset IFS
done < res.log
