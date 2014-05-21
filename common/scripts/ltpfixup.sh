#!/bin/sh

# Absolute path to this script. /home/user/bin/foo.sh
SCRIPT=$(readlink -f $0)
# Absolute path this script is in. /home/user/bin
SCRIPTPATH=`dirname $SCRIPT`
echo "Script path is: $SCRIPTPATH"

cd /opt/ltp
./runltp -p -q -f $1 -l $SCRIPTPATH/LTP_$1.log -C $SCRIPTPATH/LTP_$1.failed | tee $SCRIPTPATH/LTP_$1.out
find $SCRIPTPATH -name "LTP_$1.log" -print0 |xargs -0 cat
tar czfv $SCRIPTPATH/LTP_$1.tar.gz $SCRIPTPATH/LTP*
lava-test-case LTP_$1 --result pass
lava-test-case-attach LTP_$1 $SCRIPTPATH/LTP_$1.tar.gz
exit 0
