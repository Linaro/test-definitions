#!/bin/sh

log=$1
tail -n 2 ${log} | while read l;
do
    TC="`echo ${l} | awk -F: '{print $1}'`"
    R="`echo ${l} | awk -F: '{print $2}'`"
    IFS=','
    for c in ${R}
    do
        c=`echo $c|sed "s/^[ ]*//"`
        t="`echo $c|awk '{print $1}'`"
        v="`echo $c|awk '{print $2}'`"
        echo "${TC}_${t}: ${v} usec pass"
    done
    unset IFS
done

