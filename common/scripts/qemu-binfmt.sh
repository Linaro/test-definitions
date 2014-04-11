#!/bin/sh
# Enable automatic ARM/aarch64
#
# This is a cut down version of the qemu-binfmt-misc.sh script
#

# Base path for finding QEMU binary
BINFMT_DEVEL_MODE=""
BINFMT_VERBOSE=1
BINFMT_BASE_PATH=/usr/local/bin

# Print out some simple usage instructions
usage() {
    echo "Usage: `basename $0` options (-h)"
    echo "
This script is used to configure binfmt_misc on a system
to automatically call QEMU when a binary that it can
deal with is detected by the kernel.
"
    exit 1
}

# Register an individual binfmt
#
# Before registering the format we check for the
# existence of the binary and if VERBOSE is set we
# specify what exactly has been registered.

register_binfmt () {
    name=$1
    qbin=$2
    binfmt_string=$3

    qemu_check_path=${BINFMT_BASE_PATH}/qemu-${qbin}

    if [ -x "$qemu_check_path" ]; then
        bfmt=":$name:M::$binfmt_string:$qemu_check_path:"
        echo $bfmt > /proc/sys/fs/binfmt_misc/register
        res=$?
        if [ "$res" != "0" ]; then
            echo "Error ($res): $bfmt > /proc/sys/fs/binfmt_misc/register"
        else
            if [ -n "${BINFMT_VERBOSE}" ] ; then
                echo "registered $qemu_check_path for $name binaries"
            fi
        fi
    else
        echo "Couldn't find $qemu_check_path"
    fi
}

while getopts "h" opt
do
    case $opt in
        h)
            usage
            ;;
        *)
            echo "Unknown option."
            usage
            ;;
  esac
done

# load the binfmt_misc module
if [ ! -d /proc/sys/fs/binfmt_misc ]; then
  /sbin/modprobe binfmt_misc
fi
if [ ! -f /proc/sys/fs/binfmt_misc/register ]; then
  mount binfmt_misc -t binfmt_misc /proc/sys/fs/binfmt_misc
fi

# register the interpreter for each ARM CPU if it exists
register_binfmt arm arm "\x7fELF\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x28\x00:\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff"
register_binfmt armeb armeb "\x7fELF\x01\x02\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x28:\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff"
register_binfmt aarch64 aarch64 "\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\xb7\x00:\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff"
