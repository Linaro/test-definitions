#!/bin/sh

logfile="$1"
echo "logfile: $logfile"
while read -r line; do
    line=${line#[:space:]}
    case $line in
        TestArea:* )
            ta=${line#TestArea:}
            ;;
        TEST_* )
            tc=$line
            ;;
        RESULT=* )
            result=${line#RESULT=}
            echo "$ta-$tc:: $result"
            ;;
    esac
done < "$logfile"
