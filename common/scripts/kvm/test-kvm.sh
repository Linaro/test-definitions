#!/bin/sh

KVM_HOST_NET="kvm-host-net-1:"
KVM_GUEST_NET="kvm-guest-net-1:"
KVM_INIT="kvm-init-1:"
KVM_BOOT="kvm-boot-1:"
if [ "x$1" = "xbenchmark" ]; then
    KVM_HOST_NET="$KVM_HOST_NET 0 none"
    KVM_GUEST_NET="$KVM_GUEST_NET 0 none"
    KVM_INIT="$KVM_INIT 0 none"
    KVM_BOOT="$KVM_BOOT 0 none"
fi

dmesg|grep 'Hyp mode initialized successfully' && echo "$KVM_INIT 0 pc pass" || \
{
    echo "$KVM_INIT 0 pc fail"
    echo "$KVM_HOST_NET 0 pc skip"
    echo "$KVM_BOOT 0 pc skip"
    echo "$KVM_GUEST_NET 0 pc skip"
    exit 0
}

if hash curl 2>/dev/null; then
    EXTRACT_BUILD_NUMBER="curl -sk"
    DOWNLOAD_FILE="curl -SOk"
else
    EXTRACT_BUILD_NUMBER="wget -q --no-check-certificate -O -"
    DOWNLOAD_FILE="wget --progress=dot -e dotbytes=2M --no-check-certificate"
fi

BUILD_NUMBER=`$(echo $EXTRACT_BUILD_NUMBER) https://ci.linaro.org/jenkins/job/linux-vexpress-kvm/lastSuccessfulBuild/buildNumber`

$DOWNLOAD_FILE http://snapshots.linaro.org/ubuntu/images/kvm/$BUILD_NUMBER/kvm.qcow2.gz
$DOWNLOAD_FILE http://snapshots.linaro.org/ubuntu/images/kvm/$BUILD_NUMBER/zImage
$DOWNLOAD_FILE http://snapshots.linaro.org/ubuntu/images/kvm/$BUILD_NUMBER/vexpress-v2p-ca15-tc1.dtb

gunzip kvm.qcow2.gz
if [ $? -ne 0 ]; then
    echo "$KVM_HOST_NET 0 pc skip"
    echo "$KVM_BOOT 0 pc skip"
    echo "$KVM_GUEST_NET 0 pc skip"
    exit 0
fi

modprobe nbd max_part=16
qemu-nbd -c /dev/nbd0 kvm.qcow2
mount /dev/nbd0p2 /mnt/

cp common/scripts/kvm/kvm-lava.conf  /mnt/etc/init/kvm-lava.conf

# Build up file test-guest.sh
if [ "x$1" = "xbenchmark" ]; then
    cp /usr/bin/lat_ctx /mnt/usr/bin/lat_ctx
    cp common/scripts/lmbench.sh /mnt/root/lmbench.sh
    TEST_SCRIPT=/root/lmbench.sh
else
    cp /usr/bin/hackbench /mnt/usr/bin/hackbench
    cp common/scripts/kvm/test-rt-tests.sh /mnt/root/test-rt-tests.sh
    TEST_SCRIPT='/root/test-rt-tests.sh guest'
fi

cat >> /mnt/usr/bin/test-guest.sh <<EOF
#!/bin/sh
    exec > /root/guest.log 2>&1
    echo "$KVM_BOOT 0 pc pass"
    ping -W 4 -c 10 192.168.1.10 && echo "$KVM_GUEST_NET 0 pc pass" || echo "$KVM_GUEST_NET 0 pc fail"
    sh $TEST_SCRIPT
EOF
chmod a+x /mnt/usr/bin/test-guest.sh

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

ping -W 4 -c 10 192.168.1.10 && echo "$KVM_HOST_NET 0 pc pass" || echo "$KVM_HOST_NET 0 pc fail"

qemu-system-arm -smp 2 -m 1024 -cpu cortex-a15 -M vexpress-a15 \
	-kernel ./zImage -dtb ./vexpress-v2p-ca15-tc1.dtb \
	-append 'root=/dev/mmcblk0p2 rw rootwait mem=1024M console=ttyAMA0,38400n8' \
	-drive if=sd,cache=writeback,file=kvm.qcow2 \
	-netdev tap,id=tap0,script=no,downscript=no,ifname="tap0" \
	-device virtio-net-device,netdev=tap0 \
	-nographic -enable-kvm \
	 2>&1|tee kvm-log.txt

qemu-nbd -c /dev/nbd0 kvm.qcow2
mount /dev/nbd0p2 /mnt/

if ! grep -q "kvm-boot-1:" /mnt/root/guest.log
then
    echo "$KVM_BOOT 0 pc fail"
fi

cat /mnt/root/guest.log
cp /mnt/*.txt .
cp /mnt/root/guest.log .

umount /mnt
sync
qemu-nbd -d /dev/nbd0
