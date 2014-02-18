#!/bin/sh

if [ -f ./common/scripts/min_max_avg_parse.py ]
then
    PARSE_SCRIPT=./common/scripts/min_max_avg_parse.py
elif [-f /root/min_max_avg_parse.py ]
then
    PARSE_SCRIPT=/root/min_max_avg_parse.py
fi
for FILE in *.txt
do
    $PARSE_SCRIPT $FILE "Time:" "Seconds"
done
