#!/bin/bash
# Script to test coresight

CORESIGHT_PATH="/sys/bus/coresight/devices"

echo "ls $CORESIGHT_PATH"
ls $CORESIGHT_PATH

echo -e "SOURCE\t\tSINK\t\tRESULT"
echo -e "------\t\t----\t\t------"
for SOURCE in `ls $CORESIGHT_PATH | egrep "etm|ptm"` ; do
    for SINK in `ls $CORESIGHT_PATH | grep etb` ; do

    echo 1 > $CORESIGHT_PATH/$SINK/enable_sink
    wrt_ptr1=`cat $CORESIGHT_PATH/$SINK/status | grep wrt | awk '{print $NF}'`
    echo 1 > $CORESIGHT_PATH/$SOURCE/enable_source
    sleep 1
    echo 0 > $CORESIGHT_PATH/$SOURCE/enable_source
    wrt_ptr2=`cat $CORESIGHT_PATH/$SINK/status | grep wrt | awk '{print $NF}'`
    echo 0 > $CORESIGHT_PATH/$SINK/enable_sink

    if [ $wrt_ptr1 == $wrt_ptr2 ]; then
        RES="fail"
        else
        RES="pass"
    fi

    echo -e "$SOURCE\t$SINK\t$RES"
    lava-test-case $SOURCE-$SINK --result $RES
    done
    echo
done
