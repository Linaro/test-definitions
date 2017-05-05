#!/bin/sh -x
# shellcheck disable=SC2154
# shellcheck disable=SC1091

. ../../lib/sh-test-lib
. ../../lib/android-test-lib

JDK="openjdk-8-jdk-headless"
PKG_DEPS="curl wget zip xz-utils python-lxml python-setuptools python-pexpect aapt lib32z1-dev libc6-dev-i386 lib32gcc1 libc6:i386 libstdc++6:i386 libgcc1:i386 zlib1g:i386 libncurses5:i386"

dist_name
case "${dist}" in
    ubuntu)
        dpkg --add-architecture i386
        install_deps "${PKG_DEPS} ${JDK}"
        ;;
    *)
        error_msg "Please use Ubuntu for CTS or VTS test."
        ;;
esac

install_latest_adb
initialize_adb
adb_root
