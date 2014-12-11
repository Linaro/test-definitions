#!/bin/sh
cd common/scripts
dmesg | gawk -f dt-selftests.awk > dt-selftest-stdout.log
NO_OF_FAIL=`grep "DT-SELFTEST failed" dt-selftest-stdout.log | gawk '{print $3}'`
if [ $NO_OF_FAIL -ne 0 ] ; then
    echo "dt-selftest : failed"
else
   echo "dt-selftest : passed"
fi
