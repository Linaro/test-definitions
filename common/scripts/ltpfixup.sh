#!/bin/sh

# Absolute path to this script. /home/user/bin/foo.sh
SCRIPT=$(readlink -f $0)
# Absolute path this script is in. /home/user/bin
SCRIPTPATH=`dirname $SCRIPT`
echo "Script path is: $SCRIPTPATH"
# List of test cases
TST_CMDFILES=""
# List of test cases to be skipped
SKIPFILE=""

LTP_PATH=/opt/ltp

while getopts T:S:P: arg
    do case $arg in
        T) TST_CMDFILES="$OPTARG";;
        S) OPT=`echo $OPTARG | grep "http"`
           if [ -z $OPT ] ; then
             SKIPFILE="-S $SCRIPTPATH/ltp/$OPTARG"
           else
             wget $OPTARG
             SKIPFILE=`echo "${OPTARG##*/}"`
             SKIPFILE="-S `pwd`/$SKIPFILE"
           fi
           ;;
        P) LTP_PATH=$OPTARG;;
    esac
done

cd $LTP_PATH
RESULT=pass

exec 4>&1
error_statuses="`((./runltp -p -q -f $TST_CMDFILES -l $SCRIPTPATH/LTP_$TST_CMDFILES.log -C $SCRIPTPATH/LTP_$TST_CMDFILES.failed $SKIPFILE ||  echo "0:$?" >&3) |
        (tee $SCRIPTPATH/LTP_$TST_CMDFILES.out ||  echo "1:$?" >&3)) 3>&1 >&4`"
exec 4>&-

! echo "$error_statuses" | grep '0:' >/dev/null
if [ $? -ne 0 ]; then
    RESULT=fail
fi
lava-test-case LTP_$TST_CMDFILES --result $RESULT
find $SCRIPTPATH -name "LTP_$TST_CMDFILES.log" -print0 |xargs -0 cat
tar czfv $SCRIPTPATH/LTP_$TST_CMDFILES.tar.gz $SCRIPTPATH/LTP*
lava-test-case-attach LTP_$TST_CMDFILES $SCRIPTPATH/LTP_$TST_CMDFILES.tar.gz
exit 0
