#!/bin/sh

LOG=$1

grep ": *[0-9]" ${LOG} | sed -e "s/^ *//" -e "s/: */:/" | while read l;
do
    TC="`echo $l | cut -d':' -f1`"
    V="`echo $l | cut -d':' -f2 | sed  's/\([0-9]*\)\([a-z].*$\)/\1 --units \2/'`"
    lava-test-case "${TC}" --result pass --measurement ${V}
done
