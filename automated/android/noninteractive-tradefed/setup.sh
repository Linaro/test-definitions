#!/bin/bash -x
# shellcheck disable=SC2154
# shellcheck disable=SC1091

. ../../lib/sh-test-lib
. ../../lib/android-test-lib

## To enable running x86_64 binary on aarch64 host or inside container of it
java_path_arch_str="amd64"
if [ "X$(uname -m)" = "Xaarch64" ]; then
    java_path_arch_str="arm64"
fi
java_path="/usr/lib/jvm/java-11-openjdk-${java_path_arch_str}/bin/java"
if [ -n "${ANDROID_VERSION}" ] && echo "${ANDROID_VERSION}" | grep -E -q "aosp-android14|aosp-main"; then
    # use openjdk-17 for Android14+ versions
    java_path="/usr/lib/jvm/java-17-openjdk-${java_path_arch_str}/bin/java"
fi

dist_name
case "${dist}" in
    ubuntu)
        # make sure to use the right java version
        update-alternatives --set java ${java_path}
        ;;
    *)
        error_msg "Please use Ubuntu for CTS or VTS test."
        ;;
esac

initialize_adb
adb_root

if echo "X${SET_GOVERNOR_POWERSAVE}" | grep -i "Xtrue"; then
    echo "Set the device to be run with the powersave governor policy"
    for f_cpu_governor in $(adb shell 'su root ls /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor'); do
        adb shell "echo powersave | su root tee ${f_cpu_governor}"
    done
    adb shell 'su root cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor'
fi
