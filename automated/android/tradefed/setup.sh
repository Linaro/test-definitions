#!/bin/sh -x
# shellcheck disable=SC2154
# shellcheck disable=SC1091

. ../../lib/sh-test-lib
. ../../lib/android-test-lib

if echo "$ANDROID_VERSION" | grep aosp-master ; then
    JDK="openjdk-9-jdk-headless"
else
    JDK="openjdk-8-jdk-headless"
fi
PKG_DEPS="usbutils curl wget zip xz-utils python-lxml python-setuptools python-pexpect aapt lib32z1-dev libc6-dev-i386 lib32gcc1 libc6:i386 libstdc++6:i386 libgcc1:i386 zlib1g:i386 libncurses5:i386 python-dev python-protobuf protobuf-compiler python-virtualenv python-pip python-pexpect"

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

lava_test_dir="$(find /lava-* -maxdepth 0 -type d -regex '/lava-[0-9]+' 2>/dev/null | sort | tail -1)"
if test -f "${lava_test_dir}/secrets"; then
    # shellcheck disable=SC1090
    . "${lava_test_dir}/secrets"
fi

if [ ! -z "${AP_SSID}" ] && [ ! -z "${AP_KEY}" ]; then
    wget http://testdata.validation.linaro.org/apks/wifi/wifi.apk
    adb install wifi.apk
    adb shell am start -n com.steinwurf.adbjoinwifi/.MainActivity -e ssid "${AP_SSID}" -e password_type WPA -e password "${AP_KEY}"
fi
