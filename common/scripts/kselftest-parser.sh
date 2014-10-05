#!/bin/bash

while read l;
do
    [ -n "`echo $l|grep 'running'`" ] && test="`echo $l|sed 's/running //'`"
    [ -n "`echo $l|grep \"\[PASS\|FAIL\|SKIP\"`" ] && result=$l
    [ "${test}" -a "${result}" ] && echo "${test}: ${result}" && unset test && unset result
done < $1
