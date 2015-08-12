#!/bin/sh

LOG_FILE=$1
OUTPUT_FILE=$3
TMP_FILE="$1.$$"
BEGIN=$(cat $LOG_FILE | grep -n "^BEGIN LMBENCH" | awk -F ':' '{print $1}')
END=$(cat $LOG_FILE | grep -n "END LMBENCH" | awk -F ':' '{print $1}')
BEGINNING=$(expr $(expr $END - $BEGIN) + 1)
head -n $END $LOG_FILE | tail -n $BEGINNING >$TMP_FILE

for i in 2 8 16 20
do
    ./common/scripts/min_max_avg_parse.py $TMP_FILE "^$i" $2 "64_$i" >>$OUTPUT_FILE
done
rm $TMP_FILE
