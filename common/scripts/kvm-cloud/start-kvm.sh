#!/bin/sh
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
    SSH_KEY=`head -1 /root/.ssh/authorized_keys`
    sed -e "s,LAVA_KEY,$SSH_KEY,g" -e "s,LOCALIP,$IP,g" common/scripts/kvm-cloud/cloudinit.txt > cloudinit.tmp
    cat cloudinit.tmp
    cloud-localds cloud.img cloudinit.tmp
}
start_qemu_x86_64_aarch64()
{
    image=$1
    configimage=$2
    qemu-system-aarch64 -smp 2 -m 1024 -cpu cortex-a57 -M virt \
        -bios QEMU_EFI.fd \
        -device virtio-blk-device,drive=image \
        -drive if=none,id=image,file=$image \
        -device virtio-blk-device,drive=cloud \
        -drive if=none,id=cloud,file=$configimage \
        -device virtio-net-device,netdev=tap0 -netdev tap,id=tap0,script=no,downscript=no,ifname=tap0 \
        -daemonize -display vnc=none \
        -serial file:kvm-amd64_aarch64.txt
}

start_qemu_aarch64_aarch64()
{
    image=$1
    configimage=$2
    qemu-system-aarch64 -smp 2 -m 1024 -cpu host -M virt \
        -bios QEMU_EFI.fd \
        -device virtio-blk-device,drive=image \
        -drive if=none,id=image,file=$image \
        -device virtio-blk-device,drive=cloud \
        -drive if=none,id=cloud,file=$configimage \
        -device virtio-net-device,netdev=tap0 -netdev tap,id=tap0,script=no,downscript=no,ifname=tap0 \
        -daemonize -enable-kvm -display vnc=none \
        -serial file:kvm-aarch64_aarch64.txt
}

start_qemu_aarch64_armv7l()
{
    image=$1
    configimage=$2
    qemu-system-aarch64 -smp 2 -m 1024 -cpu host,aarch64=off -M virt \
        -kernel ./zImage \
        -append 'root=/dev/vda2 rw rootwait mem=1024M console=ttyAMA0,38400n8' \
        -device virtio-blk-device,drive=image \
        -drive if=none,id=image,file=$image \
        -device virtio-blk-device,drive=cloud \
        -drive if=none,id=cloud,file=$configimage \
        -device virtio-net-device,netdev=tap0 -netdev tap,id=tap0,script=no,downscript=no,ifname=tap0 \
        -daemonize -enable-kvm -display vnc=none \
        -serial file:kvm-aarch64_armv7l.txt
}

start_qemu_armv7l_armv7l()
{
    image=$1
    configimage=$2
    qemu-system-arm -smp 2 -m 1024 -cpu cortex-a15 -M vexpress-a15 \
        -kernel ./zImage -dtb ./vexpress-v2p-ca15-tc1.dtb \
        -append 'root=/dev/vda2 rw rootwait mem=1024M console=ttyAMA0,38400n8' \
        -device virtio-blk-device,drive=image \
        -drive if=none,id=image,file=$image \
        -device virtio-blk-device,drive=cloud \
        -drive if=none,id=cloud,file=$configimage \
        -device virtio-net-device,netdev=tap0 -netdev tap,id=tap0,script=no,downscript=no,ifname=tap0 \
        -daemonize -enable-kvm -display vnc=none \
        -serial file:kvm-armv7l_armv7l.txt
}

# This testcase expects a predefined br0 to connect to
tunctl -u root
ifconfig tap0 0.0.0.0 up
brctl addif br0 tap0

if [ ! -e /etc/qemu/bridge.conf ]
then
     mkdir -p /etc/qemu
     echo allow br0 > /etc/qemu/bridge.conf
fi

ARCH=`uname -m`
GUEST_ARCH=$1
GUEST_IMAGE=$2
DOWNLOAD_FILE="curl --retry 8 -SOL -# "

IMAGE=`basename $GUEST_IMAGE`
[ -r $IMAGE ]||$DOWNLOAD_FILE $GUEST_IMAGE
$DOWNLOAD_FILE https://releases.linaro.org/components/kernel/uefi-linaro/15.12/release/qemu64/QEMU_EFI.fd

configure_guest
ls -l .
env|sort

start_qemu_${ARCH}_${GUEST_ARCH} ${IMAGE} cloud.img

ps aux|grep qemu
sleep 10
ls *.txt

tail *.txt
