#!/bin/sh
#
# Build and Run the LTP Tests in script form
#
# This is to work around doing the build steps in the yaml which would need
# magic chroot support (or a lot of hacking to exsiting script)
#
# ensure we follow the steps we run and bomb out
set -x
set -e


LTP_RELEASE=20130904

# Print out some simple usage instructions
usage() {
    echo "Usage: `basename $0` [-r RELEASE] (install|run)"
    echo ""
    echo "This script is used to install or run the LTP tests."
    exit 1
}

# Download and install the LTP tests
install_ltp() {
    mkdir -p /home/ltp
    cd /home/ltp
    if [ "x${LTP_RELEASE}" = "xHEAD" ]; then
        git clone http://github.com/linux-test-project/ltp.git .
        make autotools
    else
        wget https://github.com/linux-test-project/ltp/archive/${LTP_RELEASE}.tar.gz
        tar --strip-components=1 -xf ${LTP_RELEASE}.tar.gz
    fi
    mkdir build
    ./configure --prefix=$(readlink -f build)
    make all
    make SKIP_IDCHECK=1 install
}

run_ltp() {
    cd /home/ltp/build
    ./runltp -f syscalls -p -q
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

case $1 in
    install)
        install_ltp
        ;;
    run)
        run_ltp
        ;;
    *)
        echo "Unknown command $1"
        usage
        ;;
esac

exit 0
