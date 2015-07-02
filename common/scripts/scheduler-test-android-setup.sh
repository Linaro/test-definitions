# Detect Android and do the needful
if [ -e /system/build.prop ]; then
    mount -o rw,remount /
    mkdir -p /bin
    cp /system/bin/sh /bin/sh
fi
