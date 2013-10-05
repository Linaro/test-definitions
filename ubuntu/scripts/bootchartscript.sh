#!/bin/sh

base="$(hostname -s)-$(lsb_release -sc)-$(date +%Y%m%d)"

# Wait for log files to become available
sleep 60
file=`find /var/log/bootchart/ -name "$base-*.tgz"`
if [ -z "$file" ]; then
    sleep 60
fi
file=`find /var/log/bootchart/ -name "$base-*.tgz"`
if [ -z "$file" ]; then
    echo "No bootchart log file available"
    exit 1
fi

count=1
while [ -e "/var/log/bootchart/$base-$count.tgz" -o -e "/var/log/bootchart/$base-$count.png" -o -e "/var/log/bootchart/$base-$count.svg" ]
do
    count=$(( $count + 1 ))
done
count=$(( $count - 1 ))

BASE="/var/log/bootchart/$base-$count"
TARBALL="$BASE.tgz"

python $PWD/bootcharttest.py $TARBALL -q > bootchart.log
