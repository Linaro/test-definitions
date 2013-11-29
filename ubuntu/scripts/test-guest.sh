#! /bin/bash
#
# Xen script to test that guest is booting
#
# Copyright (C) 2013, Linaro Limited.
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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# Author: Julien Grall <julien.grall@linaro.org>
#

dir=`dirname "$0"`
root="$dir/../../"

source "$dir/include/sh-test-lib"

set -x -e

# check we're root
if ! check_root; then
    error_msg "Please run the test case as root"
fi

# Test case: check the guest is running correctly
TEST="guest_is_running"

# FIXME: Harcode the number for now
ROOTFS_BUILD_NUMBER=536
ROOTFS_BUILD_DATE=20131125
ROOTFS_BUILD_FILENAME="vexpress-raring_nano_$ROOTFS_BUILD_DATE-$ROOTFS_BUILD_NUMBER.img"
ROOTFS_BUILD_URL="https://snapshots.linaro.org/ubuntu/pre-built/vexpress/$ROOTFS_BUILD_NUMBER/$ROOTFS_BUILD_FILENAME.gz"

rm -f $ROOTFS_BUILD_FILENAME $ROOTFS_BUILD_FILENAME.gz

# FIXME: use wget instead
wget --no-check-certificate $ROOTFS_BUILD_URL
#cp ~/$ROOTFS_BUILD_FILENAME.gz $ROOTFS_BUILD_FILENAME.gz

# Extract the image
gunzip $ROOTFS_BUILD_FILENAME.gz

# We assume that we always map to /dev/mapper/loop0*
kpartx -a -v $ROOTFS_BUILD_FILENAME

# Extract the zImage from the image
mount /dev/mapper/loop0p1 /media
dd if=/media/uImage ibs=64 skip=1 of=zImage
umount /media

#  Prepare the image by copying usefull file
mount /dev/mapper/loop0p2 /media

# Copy hvc0 initscript
cp $root/files/hvc0.conf /media/etc/init/hvc0.conf

# Copy hackbench
cp /usr/bin/hackbench /media/usr/bin/hackbench

# Copy tests
cp $root/files/test-rt-tests.sh /media/root/test-rt-tests.sh
cp $root/files/xen-lava.conf /media/etc/init/xen-lava.conf

# FIXME: Disable network for now
cp $root/files/interfaces /media/etc/network/interfaces

umount /media
kpartx -d $ROOTFS_BUILD_FILENAME

# Create the guest
loop=`losetup -f --show $ROOTFS_BUILD_FILENAME`

xl -vvv create $root/files/guest1.xl

# Disable exit on error during the waiting loop

set +o errexit
while [ true ]; do
    xl list guest1 > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        break
    fi
    sleep 60
done

set -e

losetup -d $loop

if ! grep -q "xen-boot-1:" /var/log/xen/console/guest-guest1.log; then
    echo "xen-boot-1: FAIL"
    fail_test "Guest was not running"
    exit 1
fi

pass_test

# clean exit so lava-test can trust the results
exit 0
