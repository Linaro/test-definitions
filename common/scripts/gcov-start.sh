#!/bin/sh

df -h

echo -n "LAVA gcov-enabled: "
[ -e /sys/kernel/debug/gcov/ ] && echo "pass" || echo "fail"

echo -n "LAVA gcov-collecting: "
kdir=`find /sys/kernel/debug/gcov/ -type d|grep kernel/gcov`
[ -e $kdir/base.gcda ] && echo "pass" || echo "fail"

# Currently we only support arndale gcov build
BUILD_NUMBER=`wget -q --no-check-certificate -O - https://ci.linaro.org/jenkins/job/linux-gcov/hwpack=arndale,label=kernel_cloud/lastSuccessfulBuild/buildNumber`
BASE_URL=http://snapshots.linaro.org/kernel-hwpack/linux-gcov-arndale/${BUILD_NUMBER}
if [ $# -gt 0 ]; then
    BASE_URL=http://snapshots.linaro.org/kernel-hwpack/linux-gcov-arndale/$1
fi
echo $BASE_URL
wget --progress=dot $BASE_URL/gcov-arndale-rootfs.tar.gz -O -|tar xzf - --strip-components=1 -C /

df -h
