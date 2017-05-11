#!/bin/bash
#
# Copyright (C) 2010 - 2016, Linaro Limited.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# Maintainer: Riku Voipio <riku.voipio@linaro.org>

# Create cloud-config image to set up credentials for image
configure_guest()
{
    IP=`ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | cut -f1  -d'/'`
    SSH_KEY=`head -1 /root/.ssh/authorized_keys||head -1 $HOME/.ssh/authorized_keys`
    sed -e "s,LAVA_KEY,$SSH_KEY,g" -e "s,LOCALIP,$IP,g" cloudinit.txt > cloudinit.tmp
    cat cloudinit.tmp
    cloud-localds cloud.img cloudinit.tmp
}

# Download url and puts the filename of downloaded file in first argument
download_file()
{
    local _outvar=$1
    local url=$2
    local filename=`basename $url`
    if [ ! -e $filename ]
    then
        if [ -z $url -o $url = none ]
        then
            >&2 echo "Error, url for $_outvar not set!"
            exit 2
        fi
        if ! curl --retry 3 -SsOL $url
        then
            >&2 echo "Error downloading $url for $_outvar"
            exit 3
        fi
    fi
    eval $_outvar=\$filename
}

start_qemu_x86_64_aarch64()
{
    image=$1
    download_file efi $GUEST_FIRMWARE

    set -x
    qemu-system-aarch64 -smp $GUEST_CORES -m ${GUEST_RAM} -cpu cortex-a57 -M virt \
        -bios $efi \
        -device virtio-blk-device,drive=image \
        -drive if=none,id=image,file=$image \
        -device virtio-blk-device,drive=cloud \
        -drive if=none,id=cloud,file=cloud.img \
        -device virtio-net-device,netdev=tap0 -netdev tap,id=tap0,script=no,downscript=no,ifname=tap0 \
        -daemonize -display vnc=none \
        -pidfile /run/qemu.pid \
        -serial file:qemu_aarch64.log
}

start_qemu_aarch64_aarch64()
{
    image=$1
    download_file efi $GUEST_FIRMWARE

    set -x
    qemu-system-aarch64 -smp $GUEST_CORES -m ${GUEST_RAM} -cpu host -M virt \
        -bios $efi \
        -device virtio-blk-device,drive=image \
        -drive if=none,id=image,file=$image \
        -device virtio-blk-device,drive=cloud \
        -drive if=none,id=cloud,file=cloud.img \
        -device virtio-net-device,netdev=tap0 -netdev tap,id=tap0,script=no,downscript=no,ifname=tap0 \
        -daemonize -enable-kvm -display vnc=none \
        -pidfile /run/qemu.pid \
        -serial file:kvm-aarch64_aarch64.log
}

start_qemu_x86_64_armv7l()
{
    image=$1
    download_file kernel $GUEST_KERNEL

    set -x
    qemu-system-arm -smp $GUEST_CORES -m ${GUEST_RAM} -cpu cortex-a15 -M virt \
        -kernel $kernel \
        -append "root=/dev/vdb1 rw rootwait mem=${GUEST_RAM}M console=ttyAMA0,38400n8" \
        -device virtio-blk-device,drive=image \
        -drive if=none,id=image,file=$image \
        -device virtio-blk-device,drive=cloud \
        -drive if=none,id=cloud,file=cloud.img \
        -device virtio-net-device,netdev=tap0 -netdev tap,id=tap0,script=no,downscript=no,ifname=tap0 \
        -daemonize -display vnc=none \
        -serial file:qemu_armv7l.log
}

start_qemu_aarch64_armv7l()
{
    image=$1
    download_file kernel $GUEST_KERNEL

    set -x
    qemu-system-aarch64 -smp $GUEST_CORES -m ${GUEST_RAM} -cpu host,aarch64=off -M virt \
        -kernel $kernel \
        -append "root=/dev/vdb1 rw rootwait mem=${GUEST_RAM}M console=ttyAMA0,38400n8" \
        -device virtio-blk-device,drive=image \
        -drive if=none,id=image,file=$image \
        -device virtio-blk-device,drive=cloud \
        -drive if=none,id=cloud,file=cloud.img \
        -device virtio-net-device,netdev=tap0 -netdev tap,id=tap0,script=no,downscript=no,ifname=tap0 \
        -daemonize -enable-kvm -display vnc=none \
        -pidfile /run/qemu.pid \
        -serial file:kvm-aarch64_armv7l.log
}

start_qemu_armv7l_armv7l()
{
    image=$1
    download_file kernel $GUEST_KERNEL

    set -x
    qemu-system-arm -smp $GUEST_CORES -m ${GUEST_RAM} -cpu cortex-a15 -M vexpress-a15 \
        -kernel $kernel \
        -append "root=/dev/vdb1 rw rootwait mem=${GUEST_RAM}M console=ttyAMA0,38400n8" \
        -device virtio-blk-device,drive=image \
        -drive if=none,id=image,file=$image \
        -device virtio-blk-device,drive=cloud \
        -drive if=none,id=cloud,file=cloud.img \
        -device virtio-net-device,netdev=tap0 -netdev tap,id=tap0,script=no,downscript=no,ifname=tap0 \
        -daemonize -enable-kvm -display vnc=none \
        -pidfile /run/qemu.pid \
        -serial file:kvm-armv7l_armv7l.log
}

# This testcase expects a predefined br0 to connect to
tunctl -u root
ifconfig tap0 0.0.0.0 up
brctl addif br0 tap0

ARCH=`uname -m`
GUEST_ARCH=$1
GUEST_IMAGE=$2
GUEST_FIRMWARE=$3
GUEST_KERNEL=$4
GUEST_CORES=${5:-2}
GUEST_RAM=${6:-1024}

download_file IMAGE $GUEST_IMAGE
configure_guest

if grep -q Juno /proc/device-tree/model
then
    echo "Juno detected, forcing a53 cluster"
    hwloc-bind socket:0 --pid $$
fi

start_qemu_${ARCH}_${GUEST_ARCH} ${IMAGE}
sleep 10
tail *.log
