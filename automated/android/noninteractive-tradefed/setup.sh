#!/bin/bash -x
# shellcheck disable=SC2154
# shellcheck disable=SC1091

. ../../lib/sh-test-lib
. ../../lib/android-test-lib

SKIP_INSTALL=${1:-"false"}
JDK="openjdk-11-jdk-headless"
java_path="/usr/lib/jvm/java-11-openjdk-amd64/bin/java"
if [ -n "${ANDROID_VERSION}" ] && echo "${ANDROID_VERSION}" | grep -q  "aosp-android14"; then
    # use openjdk-17 for Android14+ versions
    JDK="openjdk-17-jdk-headless"
    java_path="/usr/lib/jvm/java-17-openjdk-amd64/bin/java"
fi

PKG_DEPS="aapt apt-utils bzip2 coreutils curl git lib32gcc-s1-amd64-cross libcurl4 protobuf-compiler psmisc python3 python-is-python3 python3-lxml python3-pexpect python3-protobuf python3-setuptools sudo tar unzip usbutils wget xz-utils zip "

dist_name
case "${dist}" in
    ubuntu)
        dpkg --add-architecture i386
        apt-get update -q
        install_deps "${PKG_DEPS} ${JDK}" "${SKIP_INSTALL}"
        # make sure to use the right java version
        update-alternatives --set java ${java_path}
        ;;
    *)
        error_msg "Please use Ubuntu for CTS or VTS test."
        ;;
esac

# Only aosp-master need the python version check.
if [ -n "${ANDROID_VERSION}" ] && echo "${ANDROID_VERSION}" | grep -q  "aosp-master"; then
    chech_python_version "$(python --verison)" "3.8" "Error"
fi
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
