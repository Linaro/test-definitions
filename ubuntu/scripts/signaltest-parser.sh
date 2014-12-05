#!/bin/sh

LOG=$1
tail -n3 ${LOG} > tmp.log
mv tmp.log ${LOG}
sed -i "s/\x1b\[[0-9]A//" ${LOG}    # Remove control code
S=`tail -n1 ${LOG} | sed -e "s/.*Min/Min/" -e "s/\([0-9]\) /\1; /g" -e "s/:\s\+/=/g"`
eval $S

echo "signaltest_min: ${Min} pass"
echo "signaltest_act: ${Act} pass"
echo "signaltest_avg: ${Avg} pass"
echo "signaltest_max: ${Max} pass"
