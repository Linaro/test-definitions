#!/bin/sh -x
while true;
do
    date
    fastboot boot /lava-lxc/*boot*.img
    sleep 30
done
