#!/bin/sh

. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
LOG_FILE="${OUTPUT}/pritee_test_utility.log"
RESULT_FILE="${OUTPUT}/result.txt"
DEFAULT_OPTS="-drmpath:/usr/share/playready"
OPTS=${DEFAULT_OPTS}

if [ -n "$1" ]; then
    OPTS="$1"
fi

create_out_dir "${OUTPUT}"

chmod a+x /usr/bin/pritee_test_utility.exe
/usr/bin/pritee_test_utility.exe "${OPTS}" | tee "${LOG_FILE}"

while read -r line; do
    line=$(echo "${line}" | tr -d '[:space:]')
    case $line in
        TestArea:* )
            ta=${line#TestArea:}
            ;;
        TEST_* )
            tc=$line
            ;;
        RESULT=* )
            result=${line#RESULT=}
            result=$(echo "${result}" | tr '[:upper:]' '[:lower:]')
            echo "${ta}-${tc} ${result}" >> "${RESULT_FILE}"
            ;;
    esac
done < "${LOG_FILE}"
