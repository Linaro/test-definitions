#!/bin/sh -x

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
# shellcheck disable=SC1091
. ../../lib/android-test-lib

SKIP_INSTALL="false"
TIMEOUT="300"
JDK="openjdk-8-jdk-headless"
PKG_DEPS="curl wget zip xz-utils python-lxml python-setuptools python-pexpect aapt android-tools-adb lib32z1-dev libc6-dev-i386 lib32gcc1 libc6:i386 libstdc++6:i386 libgcc1:i386 zlib1g:i386 libncurses5:i386"
TEST_URL="http://testdata.validation.linaro.org/cts/android-cts-7.1_r1.zip"
TEST_PARAMS="run cts -m CtsBionicTestCases --abi arm64-v8a --disable-reboot --skip-preconditions --skip-device-info"
TEST_PATH="android-cts"
RESULT_FILE="$(pwd)/output/result.txt"
export RESULT_FILE

dist_name
dist_info
# shellcheck disable=SC2154
case "${dist}" in
    debian)
        dpkg --add-architecture i386
        dist_info
        echo "deb [arch=amd64,i386] http://ftp.us.debian.org/debian ${Codename} main non-free contrib" > /etc/apt/sources.list.d/tradefed.list
        if [ "${Codename}" != "sid" ]; then
            echo "deb http://ftp.debian.org/debian ${Codename}-backports main" >> /etc/apt/sources.list.d/tradefed.list
        fi
        cat /etc/apt/sources.list.d/tradefed.list
        apt-get update || true
        install_deps "${JDK}" || install_deps "-t ${Codename}-backports ${JDK}"
        install_deps "${PKG_DEPS}"
        ;;
    *)
        install_deps "${PKG_DEPS} ${JDK}"
        ;;
esac

install_latest_adb
initialize_adb
adb_root
