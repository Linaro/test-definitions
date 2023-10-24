#!/bin/bash -x
# shellcheck disable=SC2154
# shellcheck disable=SC1091

. ../../lib/sh-test-lib
. ../../lib/android-test-lib

java_path="/usr/lib/jvm/java-11-openjdk-amd64/bin/java"
if [ -n "${ANDROID_VERSION}" ] && echo "${ANDROID_VERSION}" | grep -E -q "aosp-android14|aosp-main"; then
    # use openjdk-17 for Android14+ versions
    java_path="/usr/lib/jvm/java-17-openjdk-amd64/bin/java"
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

install_latest_adb
initialize_adb
adb_root

if echo "X${SET_GOVERNOR_POWERSAVE}" | grep -i "Xtrue"; then
    echo "Set the device to be run with the powersave governor policy"
    for f_cpu_governor in $(adb shell 'su root ls /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor'); do
        adb shell "echo powersave | su root tee ${f_cpu_governor}"
    done
    adb shell 'su root cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor'
fi
