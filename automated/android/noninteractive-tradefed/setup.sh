#!/bin/bash -x
# shellcheck disable=SC2154
# shellcheck disable=SC1091

. ../../lib/sh-test-lib
. ../../lib/android-test-lib

JDK="openjdk-8-jdk-headless"
if [ -n "${ANDROID_VERSION}" ] && echo "${ANDROID_VERSION}" | grep -q  "aosp-master"; then
    # only use openjdk-11 for aosp master version
    JDK="openjdk-11-jdk-headless"
#elif 8.1/9.0/android10
#   JDK="openjdk-8-jdk-headless"
fi

PKG_DEPS="coreutils usbutils curl wget zip xz-utils python-lxml python-setuptools python-pexpect aapt lib32z1-dev libc6-dev-i386 lib32gcc1 libc6:i386 libstdc++6:i386 libgcc1:i386 zlib1g:i386 libncurses5:i386 python-dev python-protobuf protobuf-compiler python-virtualenv python-pip python-pexpect psmisc"

dist_name
case "${dist}" in
    ubuntu)
        dpkg --add-architecture i386
        apt-get update -q
        install_deps "${PKG_DEPS} ${JDK}"
        ;;
    *)
        error_msg "Please use Ubuntu for CTS or VTS test."
        ;;
esac

install_latest_adb
initialize_adb
adb_root
