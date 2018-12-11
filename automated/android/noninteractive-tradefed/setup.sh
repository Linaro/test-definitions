#!/bin/bash -x
# shellcheck disable=SC2154
# shellcheck disable=SC1091

. ../../lib/sh-test-lib
. ../../lib/android-test-lib

# ANDROID_VERSION was set in the format like change here:
# https://review.linaro.org/#/c/ci/job/configs/+/29367/
if [ -z "${ANDROID_VERSION}" ]; then
    # install jdk8 when nothing specified
    # to avoid regression
    JDK="openjdk-8-jdk-headless"
elif echo "${ANDROID_VERSION}" | grep -q  "android-8\." ; then
    # install jdk8 for Oreo builds, both 8.0 and 8.1
    JDK="openjdk-8-jdk-headless"
else
    # Use Jdk9 for all other builds
    JDK="openjdk-9-jdk-headless"
fi
PKG_DEPS="usbutils curl wget zip xz-utils python-lxml python-setuptools python-pexpect aapt lib32z1-dev libc6-dev-i386 lib32gcc1 libc6:i386 libstdc++6:i386 libgcc1:i386 zlib1g:i386 libncurses5:i386 python-dev python-protobuf protobuf-compiler python-virtualenv python-pip python-pexpect psmisc"

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
