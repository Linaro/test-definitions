#!/bin/sh
#
# Build and the LTP Tests in script form
#
# This is to work around doing the build steps in the yaml which would need
# magic chroot support (or a lot of hacking to exsiting script)
#
# ensure we follow the steps we run and bomb out
set -x
set -e

LTP_RELEASE=20140422

# Print out some simple usage instructions
usage() {
    echo "Usage: `basename $0` [-r RELEASE] <additional configure options>"
    echo ""
    echo "This script is used to install or run the LTP tests."
    exit 1
}

while getopts "hr:" opt
do
    case $opt in
        h)
            usage
            ;;
        r)
            LTP_RELEASE=$OPTARG
            ;;

        *)
            echo "Unknown option."
            usage
            ;;
    esac
done

shift $(( $OPTIND -1 ))

# Download and install the LTP tests
mkdir -p /home/ltp
cd /home/ltp
if [ "x${LTP_RELEASE}" = "xHEAD" ]; then
    git clone http://github.com/linux-test-project/ltp.git .
    make autotools
else
    wget http://sourceforge.net/projects/ltp/files/LTP%20Source/ltp-${LTP_RELEASE}/ltp-full-${LTP_RELEASE}.tar.xz
    tar --strip-components=1 -xf ltp-full-${LTP_RELEASE}.tar.xz
fi
mkdir build
./configure --prefix=$(readlink -f build) $@
make all
make SKIP_IDCHECK=1 install

exit 0
