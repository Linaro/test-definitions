#!/bin/bash
    lshw > lshw.txt
if grep -E 'core' lshw.txt
then
    lava-test-case user-space-lshw-core-present --result pass
else
    lava-test-case user-space-lshw-core-present --result fail
fi
if grep 'firmware' lshw.txt
then
    lava-test-case user-space-lshw-firmware-has-info --result pass
else
    lava-test-case user-space-lshw-firmware-has-info --result fail
fi
if grep 'cpu' lshw.txt
then
    lava-test-case user-space-lshw-cpu-has-info --result pass
else
    lava-test-case user-space-lshw-cpu-has-info --result fail
fi
if grep 'network' lshw.txt
then
    lava-test-case user-space-lshw-network-has-info --result pass
else
    lava-test-case user-space-lshw-network-has-info --result fail
fi
if grep 'storage' lshw.txt
then
    lava-test-case user-space-lshw-storage-has-info --result pass
else
    lava-test-case user-space-lshw-storage-has-info --result fail
fi
cat lshw.txt
rm lshw.txt
