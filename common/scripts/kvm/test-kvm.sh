#!/bin/sh
#
# Copyright (C) 2010 - 2014, Linaro Limited.
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

tamper_guest()
{
    guest=$1
    prefix=$2
    PREFIX_KVM_BOOT=${prefix}-$KVM_BOOT
    PREFIX_KVM_GUEST_NET=${prefix}-$KVM_GUEST_NET

    if [ ! -r $guest ]; then
        echo "$PREFIX_KVM_BOOT 0 pc skip"
        echo "$PREFIX_KVM_GUEST_NET 0 pc skip"
        exit 0
    fi

    qemu-nbd -c /dev/nbd0 $guest
    sleep 2
    mount /dev/nbd0p2 /mnt/

    cp common/scripts/kvm/kvm-lava.conf  /mnt/etc/init/kvm-lava.conf

    # Build up file test-guest.sh
    if [ "x$1" = "xbenchmark" ]; then
        cp /usr/bin/lat_ctx /mnt/usr/bin/lat_ctx
        cp common/scripts/lmbench.sh /mnt/root/lmbench.sh
        TEST_SCRIPT=/root/lmbench.sh
    else
        cp hackbench-${prefix} /mnt/usr/bin/hackbench
        cp common/scripts/kvm/test-rt-tests.sh /mnt/root/test-rt-tests.sh
        TEST_SCRIPT="/root/test-rt-tests.sh ${prefix}-guest"
    fi

    cat >> /mnt/usr/bin/test-guest.sh <<EOF
#!/bin/sh
    exec > /root/guest.log 2>&1
    echo "$PREFIX_KVM_BOOT 0 pc pass"
    ping -w 20 -c 10 10.0.0.1 && echo "$PREFIX_KVM_GUEST_NET 0 pc pass" || echo "$PREFIX_KVM_GUEST_NET 0 pc fail"
    sh $TEST_SCRIPT
EOF
    chmod a+x /mnt/usr/bin/test-guest.sh

    umount /mnt
    sync
    qemu-nbd -d /dev/nbd0
}

get_results()
{
    guest=$1
    prefix=$2
    qemu-nbd -c /dev/nbd0 $guest
    sleep 2
    mount /dev/nbd0p2 /mnt/

    if ! grep -q "kvm-boot-1:" /mnt/root/guest.log
    then
        echo "${prefix}-${KVM_BOOT} 0 pc fail"
    fi
    echo ${prefix}-guest logs:
    cp /mnt/*.txt .
    cp /mnt/root/guest.log ./${prefix}-guest.log
    cat ./${prefix}-guest.log
    umount /mnt
    sync
    qemu-nbd -d /dev/nbd0
}

deadline() {
    timeout=$1
    binary=$2
    set +o errexit
    while [ true ]; do
        pid=`pidof $binary`
        if [ $? -ne 0 ]; then
            break
        fi
        sleep 60
        timeout=$((timeout - 1))
        if [ $timeout -eq 0 ]; then
            kill $pid
            sleep 10
            kill -9 $pid
        break
        fi
    done
}

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

curl 2>/dev/null
if [ $? = 2 ]; then
    EXTRACT_BUILD_NUMBER="curl -sk"
    DOWNLOAD_FILE="curl -SOk"
else
    EXTRACT_BUILD_NUMBER="wget -q --no-check-certificate -O -"
    DOWNLOAD_FILE="wget --no-clobber --progress=dot -e dotbytes=2M --no-check-certificate"
fi

BUILD_NUMBER_GUEST=`$(echo $EXTRACT_BUILD_NUMBER) https://ci.linaro.org/job/kvm-guest-image/lastSuccessfulBuild/buildNumber`

$DOWNLOAD_FILE http://snapshots.linaro.org/ubuntu/images/kvm-guest/$BUILD_NUMBER_GUEST/kvm-arm32.qcow2.gz
$DOWNLOAD_FILE http://snapshots.linaro.org/ubuntu/images/kvm-guest/$BUILD_NUMBER_GUEST/zImage-vexpress
$DOWNLOAD_FILE http://snapshots.linaro.org/ubuntu/images/kvm-guest/$BUILD_NUMBER_GUEST/vexpress-v2p-ca15-tc1.dtb
gunzip kvm-arm32.qcow2.gz

case ${ARCH} in
    armv7l)
        modprobe nbd max_part=16
        ;;
    aarch64)
        hwpack=`uname -r|sed -e's,.*-,,'`
        BUILD_NUMBER_HOST=`$(echo $EXTRACT_BUILD_NUMBER) https://ci.linaro.org/job/linux-kvm/hwpack=${hwpack},label=docker-utopic/lastSuccessfulBuild/buildNumber`
        $DOWNLOAD_FILE http://snapshots.linaro.org/ubuntu/images/kvm-guest/$BUILD_NUMBER_GUEST/kvm-arm64.qcow2.gz
        $DOWNLOAD_FILE http://snapshots.linaro.org/ubuntu/images/kvm/$BUILD_NUMBER_HOST/Image-${hwpack}
        $DOWNLOAD_FILE http://snapshots.linaro.org/ubuntu/images/kvm/$BUILD_NUMBER_HOST/nbd-${hwpack}.ko.gz
        gunzip kvm-arm64.qcow2.gz
        zcat nbd-${hwpack}.ko.gz > nbd.ko
        insmod nbd.ko max_part=16
        tamper_guest kvm-arm64.qcow2 aarch64
        ;;
    *)
        echo unknown arch ${ARCH}
        exit 1
        ;;
esac


echo 0 2000000 > /proc/sys/net/ipv4/ping_group_range

tamper_guest kvm-arm32.qcow2 armv7l

case ${ARCH} in
    armv7l)
        echo "setting up and testing networking bridge for guest"
        brctl addbr br0
        tunctl -u root
        ifconfig eth0 0.0.0.0 up
        ifconfig tap0 0.0.0.0 up
        brctl addif br0 eth0
        brctl addif br0 tap0
        udhcpc -t 10 -i br0
esac

ping -W 4 -c 10 10.0.0.1 && echo "$KVM_HOST_NET 0 pc pass" || echo "$KVM_HOST_NET 0 pc fail"

case ${ARCH} in
    armv7l)
        deadline 60 qemu-system-arm &
        qemu-system-arm --version
        qemu-system-arm -smp 2 -m 1024 -cpu cortex-a15 -M vexpress-a15 \
        -kernel ./zImage-vexpress -dtb ./vexpress-v2p-ca15-tc1.dtb \
        -append 'root=/dev/vda2 rw rootwait mem=1024M console=ttyAMA0,38400n8' \
        -drive if=none,id=image,file=kvm-arm32.qcow2 \
        -netdev tap,id=tap0,script=no,downscript=no,ifname="tap0" \
        -device virtio-net-device,netdev=tap0 \
        -device virtio-blk-device,drive=image \
        -nographic -enable-kvm 2>&1|tee kvm-arm32.log
        ;;
    aarch64)
        # handle big.LITTLE
        hwloc-ls
        case ${hwpack} in
            juno)
                # run on a57 cluster
                bind="hwloc-bind socket:1"
                ;;
            *)
                bind=""
                ;;
        esac
        deadline 60 qemu-system-aarch64 &
        qemu-system-aarch64 --version
        echo "64bit guest test"
        $bind qemu-system-aarch64 -smp 2 -m 1024 -cpu host -M virt \
        -kernel ./Image-${hwpack} \
        -append 'root=/dev/vda2 rw rootwait mem=1024M earlyprintk=pl011,0x9000000 console=ttyAMA0,38400n8' \
        -drive if=none,id=image,file=kvm-arm64.qcow2 \
        -netdev user,id=user0 -device virtio-net-device,netdev=user0 \
        -device virtio-blk-device,drive=image \
        -nographic -enable-kvm 2>&1|tee kvm-arm64.log
        echo "32bit guest test"
        $bind qemu-system-aarch64 -smp 2 -m 1024 -cpu host,aarch64=off -M virt \
        -kernel ./zImage-vexpress \
        -append 'root=/dev/vda2 rw rootwait mem=1024M console=ttyAMA0,38400n8' \
        -drive if=none,id=image,file=kvm-arm32.qcow2 \
        -netdev user,id=user0 -device virtio-net-device,netdev=user0 \
        -device virtio-blk-device,drive=image \
        -nographic -enable-kvm 2>&1|tee kvm-arm32.log
        get_results kvm-arm64.qcow2 aarch64
        ;;
    *)
        echo unknown arch ${ARCH}
        exit 1
        ;;
esac

get_results kvm-arm32.qcow2 armv7l

ls *log *txt
rm -f md5sum.txt
