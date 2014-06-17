#!/bin/sh

for f in `find $1 -name "__STATUS_OF_TESTS"`;
do
    sed "s/^\"://" $f
done
