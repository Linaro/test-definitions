#!/bin/bash

set -e

NEW_ROOTFS=${1}

(
cd /
curl -SOL "${NEW_ROOTFS}"
unxz rpb-console-image-lkft-*.rootfs.tar.xz
mkdir -p /new_root
tar --strip-components=1 -C new_root -xf rpb-console-image-lkft-*.rootfs.tar
rm rpb-console-image-lkft-*.rootfs.tar
cd new_root
mount -t proc /proc proc/
mount --rbind /sys sys/
mount --rbind /dev dev/
mount --rbind /run run/
)
