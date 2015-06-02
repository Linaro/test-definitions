#!/bin/sh

set -x 

# Absolute path to this script. /home/user/bin/foo.sh
SCRIPT=$(readlink -f $0)
# Absolute path this script is in. /home/user/bin
SCRIPTPATH=`dirname $SCRIPT`
echo "Script path is: $SCRIPTPATH"
# testcase
JOB=""
LAVATEST="echo"

useradd --create-home --home-dir /home/lkp lkp
mkdir -p /home/lkp
chown -R lkp:lkp /home/lkp

echo 'deb http://ports.ubuntu.com/ubuntu-ports/ vivid multiverse'|sudo tee /etc/apt/sources.list.d/multiverse.list
apt-get update

LKP_PATH=/root/lkp-tests

while getopts J:P:L:A arg
    do case $arg in
        J) JOB="$OPTARG";;
        P) LKP_PATH=$OPTARG;;
        L) LAVATEST=$OPTARG;;
    esac
done
git log --oneline|head
cd ${LKP_PATH}
RESULT=pass
./sbin/split-job jobs/${JOB}.yaml
for SPLITJOB in *.yaml;
do
    LOCALRESULT=pass
    jobname=`echo $SPLITJOB|sed -e 's,.yaml,,'`
    ./bin/setup-local $SPLITJOB
    ./bin/run-local $SPLITJOB||LOCALRESULT=fail
    $LAVATEST LKP_$jobname --result $LOCALRESULT
done

./bin/lkp stat

if [ $? -ne 0 ]; then
    RESULT=fail
fi

$LAVATEST LKP_$JOB --result $RESULT
tar caf ${LKP_PATH}/lkp-${JOB}.tar.xz /result/$JOB/
exit 0
