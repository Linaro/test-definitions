#!/bin/sh

df -h

echo -n "LAVA gcov-enabled: "
[ -e /sys/kernel/debug/gcov/ ] && echo "pass" || echo "fail"

echo -n "LAVA gcov-collecting: "
kdir=`find /sys/kernel/debug/gcov/ -type d|grep kernel/gcov`
[ -e $kdir/base.gcda ] && echo "pass" || echo "fail"

BUILD_NUMBER=`wget -q --no-check-certificate -O - https://ci.linaro.org/jenkins/job/linux-gcov/hwpack=arndale,label=kernel_cloud/lastSuccessfulBuild/buildNumber`
wget -nv http://snapshots.linaro.org/kernel-hwpack/linux-gcov-arndale/${BUILD_NUMBER}/gcov-arndale-rootfs.tar.gz -O -|tar xzf - --strip-components=1 -C /

df -h

./build/runltp

lcov -c -o coverage.info && echo "LAVA gcov-read: pass" || echo "LAVA gcov-read: fail"

genhtml coverage.info -o boot_and_ltp && echo "LAVA gcov-html: pass" || echo "LAVA gcov-html: fail"
tar czf gcov-results.tar.gz boot_and_ltp
date=`date +%F`
mkdir /srv/scratch
mount -t nfs hackbox:/nfs/scratch/ /srv/scratch
cp gcov-results.tar.gz /srv/scratch/gcov-results-${date}.tar.gz
sync
umount /srv/scratch
