#!/bin/sh

set -x

PRINT_PASS='test_case_id:netserver units:none measurement:0 result:pass'
PRINT_FAIL='test_case_id:netserver units:none measurement:0 result:fail'

pgrep netserver
if [ $? -eq 0 ]; then
    echo ${PRINT_PASS}
else
    netserver && echo ${PRINT_PASS} || echo ${PRINT_FAIL}
fi
