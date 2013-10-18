#!/bin/sh

KVM_HOST_NET="kvm-host-net-1:"
KVM_GUEST_NET="kvm-guest-net-1:"
KVM_INIT="kvm-init-1:"
KVM_BOOT="kvm-boot-1:"
if [ $1 = "benchmark" ]; then
    KVM_HOST_NET="$KVM_HOST_NET 0 none"
    KVM_GUEST_NET="$KVM_GUEST_NET 0 none"
    KVM_INIT="$KVM_INIT 0 none"
    KVM_BOOT="$KVM_BOOT 0 none"
fi

dmesg|grep 'Hyp mode initialized successfully' && echo "$KVM_INIT pass" || echo "$KVM_INIT fail"

wget --no-check-certificate http://snapshots.linaro.org/kernel-hwpack/linux-vexpress-kvm/linux-vexpress-kvm/kvm.qcow2.gz
gunzip kvm.qcow2.gz

modprobe nbd max_part=16
qemu-nbd -c /dev/nbd0 kvm.qcow2
mount /dev/nbd0p2 /mnt/

cp /mnt/boot/vmlinuz-*-linaro-vexpress ./zImage
cp /mnt/lib/firmware/*-linaro-vexpress/device-tree/vexpress-v2p-ca15-tc1.dtb .
# Build up file kvm-lava.conf
cat >> /mnt/etc/init/kvm-lava.conf <<EOF
start on runlevel [23]
stop on runlevel [!23]
console output
script
    echo "$KVM_BOOT pass"
    ping -W 4 -c 10 192.168.1.10 && echo "$KVM_GUEST_NET pass" || echo "$KVM_GUEST_NET fail"
EOF
if [ $1 = "benchmark" ]; then
    cp /usr/bin/lat_ctx /mnt/usr/bin/lat_ctx
    cp common/scripts/lmbench.sh /mnt/root/lmbench.sh
    echo "    echo 'Test lmbench on guest'" >>/mnt/etc/init/kvm-lava.conf
    echo "    sh /root/lmbench.sh" >>/mnt/etc/init/kvm-lava.conf
else
    cp /usr/bin/hackbench /mnt/usr/bin/hackbench
    cp common/scripts/kvm/test-rt-tests.sh /mnt/root/test-rt-tests.sh
    echo "    echo 'Test hackbench on guest'" >>/mnt/etc/init/kvm-lava.conf
    echo "    sh /root/test-rt-tests.sh" >>/mnt/etc/init/kvm-lava.conf
fi

echo "    poweroff" >>/mnt/etc/init/kvm-lava.conf
echo "end script" >>/mnt/etc/init/kvm-lava.conf


umount /mnt
sync
qemu-nbd -d /dev/nbd0

echo setting up and testing networking bridge for guest
brctl addbr br0
tunctl -u root
ifconfig eth0 0.0.0.0 up
ifconfig tap0 0.0.0.0 up
brctl addif br0 eth0
brctl addif br0 tap0
udhcpc -t 10 -i br0

ping -W 4 -c 10 192.168.1.10 && echo "$KVM_HOST_NET pass" || echo "$KVM_HOST_NET fail"

qemu-system-arm -smp 2 -m 1024 -cpu cortex-a15 -M vexpress-a15 \
	-kernel ./zImage -dtb ./vexpress-v2p-ca15-tc1.dtb \
	-append 'root=/dev/mmcblk0p2 rw rootwait mem=1024M console=ttyAMA0,38400n8' \
	-drive if=sd,cache=writeback,file=kvm.qcow2 \
	-netdev tap,id=tap0,script=no,downscript=no,ifname="tap0" \
	-device virtio-net-device,netdev=tap0 \
	-nographic -enable-kvm \
	 2>&1|tee kvm-log.txt

if ! grep -q "kvm-boot-1:" kvm-log.txt
then
    echo "$KVM_BOOT fail"
fi
