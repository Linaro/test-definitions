#!/bin/sh

# Absolute path to this script. /home/user/bin/foo.sh
SCRIPT=$(readlink -f $0)
# Absolute path this script is in. /home/user/bin
SCRIPTPATH=`dirname $SCRIPT`
echo "Script path is: $SCRIPTPATH"

LTP_PATH=/opt/ltp
# Second parameter is used as a path to LTP installation
if [ "$#" -gt 1 ]; then
    LTP_PATH=$2
fi
cd $LTP_PATH
RESULT=pass

exec 4>&1
error_statuses="`((./runltp -p -q -f $1 -l $SCRIPTPATH/LTP_$1.log -C $SCRIPTPATH/LTP_$1.failed ||  echo "0:$?" >&3) |
        (tee $SCRIPTPATH/LTP_$1.out ||  echo "1:$?" >&3)) 3>&1 >&4`"
exec 4>&-

! echo "$error_statuses" | grep '0:' >/dev/null
if [ $? -ne 0 ]; then
    RESULT=fail
fi
lava-test-case LTP_$1 --result $RESULT
find $SCRIPTPATH -name "LTP_$1.log" -print0 |xargs -0 cat
tar czfv $SCRIPTPATH/LTP_$1.tar.gz $SCRIPTPATH/LTP*
lava-test-case-attach LTP_$1 $SCRIPTPATH/LTP_$1.tar.gz
exit 0
