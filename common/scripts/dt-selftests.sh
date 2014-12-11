#!/bin/sh
cd common/scripts
dmesg | awk -f dt-selftests.awk > dt-selftest-stdout.log
NO_OF_PASS=`grep "DT-SELFTEST passed" dt-selftest-stdout.log | awk '{print $3}'`
NO_OF_FAIL=`grep "DT-SELFTEST failed" dt-selftest-stdout.log | awk '{print $3}'`
if [ $NO_OF_FAIL -ne 0 ] ; then
    echo "test_case_id:dt-selftest-passed measurement:$NO_OF_PASS result:passed"
    echo "test_case_id:dt-selftest-failed measurement:$NO_OF_FAIL result:failed"
else
    echo "test_case_id:dt-selftest-passed measurement:$NO_OF_PASS result:passed"
    echo "test_case_id:dt-selftest-failed measurement:$NO_OF_FAIL result:passed"
fi
