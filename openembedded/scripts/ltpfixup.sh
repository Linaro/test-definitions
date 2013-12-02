#!/bin/sh

cd /opt/ltp
./runltp -p -q -f $1
find ./results -name "LTP_RUN_ON*" -print0 |xargs -0 cat
exit 0
