#!/bin/sh

BUILD_TIME=`date +%Y%m%d%H%M`

anaconda-cleanup

livemedia-creator \
    --no-virt --make-disk \
    --armplatform=None \
    --tmp=${PWD} \
    --image-name=${PWD}/F18-arndale-${BUILD_TIME}.img \
    --ks=${PWD}/fedora/scripts/build/F18-arndale-console_lava_test_in_f17.ks

ls -alh *.img
if [ $? -eq 0 ]; then
    echo "fedora-build=pass"
else
    echo "fedora-build=fail"
fi
