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

ARCH=`uname -m`

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

BUILD_NUMBER_GUEST=`$(echo $EXTRACT_BUILD_NUMBER) https://ci.linaro.org/job/kvm-guest-image/lastSuccessfulBuild/buildNumber`

case ${ARCH} in
    armv7l)
        $DOWNLOAD_FILE http://snapshots.linaro.org/ubuntu/images/kvm-guest/$BUILD_NUMBER_GUEST/kvm-arm32.qcow2.gz
        $DOWNLOAD_FILE http://snapshots.linaro.org/ubuntu/images/kvm-guest/$BUILD_NUMBER_GUEST/zImage-vexpress
        $DOWNLOAD_FILE http://snapshots.linaro.org/ubuntu/images/kvm-guest/$BUILD_NUMBER_GUEST/vexpress-v2p-ca15-tc1.dtb
        gunzip kvm-arm32.qcow2.gz
        mv kvm-arm32.qcow2 kvm.qcow2
        modprobe nbd max_part=16
        ;;
    aarch64)
        hwpack=`uname -r|sed -e's,.*-,,'`
        BUILD_NUMBER_HOST=`$(echo $EXTRACT_BUILD_NUMBER) https://ci.linaro.org/job/linux-kvm/hwpack=${hwpack},label=kernel_cloud/lastSuccessfulBuild/buildNumber`
        $DOWNLOAD_FILE http://snapshots.linaro.org/ubuntu/images/kvm-guest/$BUILD_NUMBER_GUEST/kvm-arm64.qcow2.gz
        $DOWNLOAD_FILE http://snapshots.linaro.org/ubuntu/images/kvm/$BUILD_NUMBER_HOST/Image-${hwpack}
        $DOWNLOAD_FILE http://snapshots.linaro.org/ubuntu/images/kvm/$BUILD_NUMBER_HOST/nbd-${hwpack}.ko.gz
        gunzip kvm-arm64.qcow2.gz
        gunzip nbd.ko.gz
        mv kvm-arm64.qcow2 kvm.qcow2
        insmod nbd.ko max_part=16
        ;;
    *)
        echo unknown arch ${ARCH}
        exit 1
        ;;
esac

if [ ! -r kvm.qcow2 ]; then
    echo "$KVM_HOST_NET 0 pc skip"
    echo "$KVM_BOOT 0 pc skip"
    echo "$KVM_GUEST_NET 0 pc skip"
    exit 0
fi

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

echo 0 2000000 > /proc/sys/net/ipv4/ping_group_range

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

case ${ARCH} in
    armv7l)
echo setting up and testing networking bridge for guest
brctl addbr br0
tunctl -u root
ifconfig eth0 0.0.0.0 up
ifconfig tap0 0.0.0.0 up
brctl addif br0 eth0
brctl addif br0 tap0
udhcpc -t 10 -i br0
esac

ping -W 4 -c 10 192.168.1.10 && echo "$KVM_HOST_NET 0 pc pass" || echo "$KVM_HOST_NET 0 pc fail"

case ${ARCH} in
    armv7l)
        qemu-system-arm --version
qemu-system-arm -smp 2 -m 1024 -cpu cortex-a15 -M vexpress-a15 \
	-kernel ./zImage-vexpress -dtb ./vexpress-v2p-ca15-tc1.dtb \
	-append 'root=/dev/vda2 rw rootwait mem=1024M console=ttyAMA0,38400n8' \
	-drive if=none,id=image,file=kvm.qcow2 \
	-netdev tap,id=tap0,script=no,downscript=no,ifname="tap0" \
	-device virtio-net-device,netdev=tap0 \
	-device virtio-blk-device,drive=image \
	-nographic -enable-kvm \
	 2>&1|tee kvm-log.txt
        ;;
    aarch64)
        qemu-system-aarch64 --version
qemu-system-aarch64 -smp 2 -m 1024 -cpu host -M virt \
	-kernel ./Image-mustang \
	-append 'root=/dev/vda2 rw rootwait mem=1024M earlyprintk=pl011,0x9000000 console=ttyAMA0,38400n8' \
	-drive if=none,id=image,file=kvm.qcow2 \
	-netdev user,id=user0 -device virtio-net-device,netdev=user0 \
	-device virtio-blk-device,drive=image \
	-nographic -enable-kvm \
	 2>&1|tee kvm-log.txt
        ;;
    *)
        echo unknown arch ${ARCH}
        exit 1
        ;;
esac

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
