#!/bin/sh

LOG=$1

sed -n -e "/^ Task 0/,$ p" ${LOG} > tmp.log
sed -i -e "s/ (.*//" -e "s/^\s*//" tmp.log

while read l;
do
    [ -n "`echo $l | grep '^Task'`" ] && T="$l" && continue
    [ -n "$l" ] && echo "$T $l pass"
done < tmp.log
