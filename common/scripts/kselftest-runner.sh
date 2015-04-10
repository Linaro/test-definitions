#!/bin/sh

TEST_NAME=$1
COMMAND=$(basename "$2")
DIR=$(dirname "$2")
LOG="result.log";

cd ${DIR}
ls ${COMMAND} > /dev/null 2>&1 && chmod a+x ${COMMAND}
export PATH=.:${PATH}
(${COMMAND} 2>&1 || echo "${TEST_NAME}: [FAIL]") | tee ${LOG}
if [ -n "`grep \"skip\" ${LOG}`" ]; then
    echo "${TEST_NAME}: [SKIP]";
elif [ -z "`grep \"SKIP\|FAIL\" ${LOG}`" ]; then
    echo "${TEST_NAME}: [PASS]"
elif [ -n "`grep \"FAIL\" ${LOG}`" ]; then
    echo "${TEST_NAME}: [FAIL]"
fi

while read l;
do
    [ -n "`echo $l|grep 'running'`" ] && test="`echo $l|sed 's/running //'`"
    [ -n "`echo $l|grep \"\[PASS\|FAIL\|SKIP\"`" ] && result=$l
    [ "${test}" -a "${result}" ] && echo "${test}: ${result}" && unset test && unset result
done < ${LOG}

# clean exit so that lava-test-shell can trust the results
exit 0
