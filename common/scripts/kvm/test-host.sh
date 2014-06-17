#!/bin/sh

echo "Compile hackbench"
curl 2>/dev/null
if [ $? = 2 ]; then
    DOWNLOAD_FILE="curl -SOk"
else
    DOWNLOAD_FILE="wget --progress=dot -e dotbytes=2M --no-check-certificate"
fi

$DOWNLOAD_FILE http://people.redhat.com/mingo/cfs-scheduler/tools/hackbench.c
gcc -g -Wall -O2 -o hackbench hackbench.c -lpthread
cp hackbench /usr/bin/

echo "Test hackbench on host"
sh ./common/scripts/kvm/test-rt-tests.sh
