#!/bin/sh

echo $1
while read line; do
    line="$(echo $line | tr -d '[:space:]')"
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
done < $1
