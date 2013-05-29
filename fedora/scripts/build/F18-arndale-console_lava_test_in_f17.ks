# Build a Fedora ARM (A15) Arndale board remix image using livemedia-creator
# NOTE:
#   Run livemedia-creator on and F17 host for this F18 build.
#   The tools on F18 require some changes to the kickstart
#   and the command line.

lang en_US.UTF-8
keyboard us
timezone --utc US/Eastern
auth --useshadow --enablemd5
#selinux --enforcing
selinux --disabled
#firstboot --enable
firewall --enabled --service=mdns,ssh
network --bootproto=dhcp --device=eth0 --onboot=on --activate --hostname=arndale-f18-v7hl
services --enabled=NetworkManager,sshd,chronyd --disabled=network

skipx

# Set a default root password for Fedora
rootpw --plaintext fedora

# Repositories
# apparently we must use 'url' for the install repo for livemedia-creator
url --url="http://dl.fedoraproject.org/pub/fedora-secondary/releases/18/Everything/armhfp/os/"
# incude the rest of the packges
repo --name=other --baseurl="http://dl.fedoraproject.org/pub/fedora-secondary/releases/18/Everything/armhfp/os/"
repo --name=other-up --baseurl="http://dl.fedoraproject.org/pub/fedora-secondary/releases/18/Everything/armhfp/os/"
# include a local repo to get grubby, the A15 kernel, etc.
repo --name=fwpfa --baseurl="http://tekkamanninja.fedorapeople.org/yum/f18/armhfp/os/Packages/"

#
# Define how large you want your rootfs to be
#
# NOTE: /boot and swap MUST use --asprimary to ensure '/' is 
#       the last partition in order for rootfs-resize to work.
#
bootloader --location=none
zerombr
clearpart --all
part /boot --size 200 --fstype ext3 --label=boot
part swap --size 500 --asprimary --label=swap
part / --size 2000 --fstype ext4 --label=rootfs

#
# Add all the packages after the standard packages
#
%packages --nobase
@standard

# This is a remix, so use tekkamanninja-release
-fedora-release
-fedora-logos
#for tekkamanninja repo
tekkamanninja-release
generic-logos

# install the Exynos5 kernel for the Arndale board
kernel-exynos5

# apparently none of the default groups sets the clock.
chrony

# and ifconfig would be nice.
net-tools

# we'll want to resize the rootfs on first boot
rootfs-resize

# get the uboot tools
uboot-tools


%end


# more configuration
%post --erroronfail

# set up the U-Boot config for the Arndale board
cat << EOF >> /etc/sysconfig/uboot
# settings for the Arndale board
UBOOT_IMGADDR=0x40008000
UBOOT_DEVICE=mmcblk0p1
EOF

# then remove the 'generic' kernel
#yum -y remove kernel


# Set up the bootloader configuration on the /boot partition
pushd /boot

# get the root device from fstab, typically UUID=<string>
ROOTDEV=`grep -w / /etc/fstab | cut -d ' ' -f1`

KERNEL_ADDR=0x40007000
INITRD_ADDR=0x42000000
DTB_ADDR=0x41f00000

# setup uEnv.txt
cat <<EOL > uEnv.txt
mmcargs=setenv bootargs console=\${console} root=$ROOTDEV rw rootwait  drm_kms_helper.edid_firmware=edid-1920x1080.fw
mmcload=ext2load mmc 0 $DTB_ADDR exynos5250-arndale.dtb; ext2load mmc 0 $INITRD_ADDR uInitrd; ext2load mmc 0 $KERNEL_ADDR uImage; echo Booting from mmc ...
uenvcmd=run mmcload; run mmcargs; bootm $KERNEL_ADDR $INITRD_ADDR $DTB_ADDR
EOL

popd


# datestamp this release
date +F18-%Y%m%d-test > /etc/RELEASE

# force resize of the rootfs
touch /.rootfs-repartition

# try Brendan's tip for workaround.
setfiles -v -F -e /proc -e /sys -e /dev \
  /etc/selinux/targeted/contexts/files/file_contexts /


%end


# get the files required for A15 (Arndale board) boot
# FIXME: these should be packaged as RPMs and installed via yum.

%post --nochroot

pushd /mnt/sysimage

# get the script binary for the Arndale board
wget -P boot "http://tekkamanninja.fedorapeople.org/boards/arndale/boot/exynos5250-arndale.dtb"

# install pre-built bootloader
# here assume that the --image-name=F18-arndale-${BUILD_TIME}-console_lava_test.img 
LOOP_DEV=`ls /dev/mapper/F18-arndale-*-console_lava_test`

mkdir boot/u-boot

wget -P boot/u-boot "http://tekkamanninja.fedorapeople.org/boards/arndale/u-boot/arndale-bl1.bin"
wget -P boot/u-boot "http://tekkamanninja.fedorapeople.org/boards/arndale/u-boot/smdk5250-spl.bin"
wget -P boot/u-boot "http://tekkamanninja.fedorapeople.org/boards/arndale/u-boot/u-boot.bin"

if [ -e $LOOP_DEV ] 
then
dd if=boot/u-boot/arndale-bl1.bin of=$LOOP_DEV bs=512 seek=1
dd if=boot/u-boot/smdk5250-spl.bin of=$LOOP_DEV bs=512 seek=17
dd if=boot/u-boot/u-boot.bin of=$LOOP_DEV bs=512 seek=49
fi
###############################



#for LAVA test only----start
#clean /etc/fstab
rm etc/fstab
touch etc/fstab

#auto-login as root
sed 's#^ExecStart=-/sbin/agetty -s#ExecStart=-/sbin/agetty -s  --noclear --autologin root #' lib/systemd/system/serial-getty@.service > lib/systemd/system/serial-getty@.service.tmp
mv lib/systemd/system/serial-getty@.service.tmp  lib/systemd/system/serial-getty@.service

#delete the password of root
sed -r 's/^root:.*((:.*){7})$/root:\1/' etc/shadow  > etc/shadow.tmp
mv etc/shadow.tmp etc/shadow


#disable the rootfs partition resize on first booting
rm .rootfs-repartition

#overwrite /boot/uEvn.txt for lava test
mv boot/uEnv.txt boot/uEnv.txt.org
cat <<EOL > boot/uEnv.txt
mmc rescan
mmc part 0
setenv bootcmd "'fatload mmc 0:2 0x40007000 uImage; fatload mmc 0:2 0x42000000 uInitrd; fatload mmc 0:2 0x41f00000 exynos5250-arndale.dtb; bootm 0x40007000 0x42000000 0x41f00000'"
setenv bootargs "'console=ttySAC2,115200n8  root=LABEL=testrootfs rootwait rw selinux=0'"
boot
EOL
#for LAVA test only----end

sync 

popd

%end
