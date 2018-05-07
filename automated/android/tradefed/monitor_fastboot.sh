#!/bin/sh -x
wget http://people.linaro.org/~vishal.bhoj/fastboot
chmod a+x fastboot
while true; do
./fastboot boot /lava-lxc/boot*.img
done
