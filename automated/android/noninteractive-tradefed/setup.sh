#!/bin/bash -x
# shellcheck disable=SC2154
# shellcheck disable=SC1091

. ../../lib/sh-test-lib
. ../../lib/android-test-lib

get_required_java_version() {
    local android_version="${1}"
    case "${android_version}" in
        *android11*|*android12*|*android13*) echo "11" ;;
        # use openjdk-17 for Android14+ versions
        *android14*|*android15*|*aosp-main*) echo "17" ;;
        # use openjdk-21 for Android16+ versions
        *android16*|*aosp-latest*) echo "21" ;;
        *) echo "21" ;;
    esac
}
## To enable running x86_64 binary on aarch64 host or inside container of it
java_path_arch_str="amd64"
if [ "X$(uname -m)" = "Xaarch64" ]; then
    java_path_arch_str="arm64"
fi

# shellcheck disable=SC2153
java_version=$(get_required_java_version "${ANDROID_VERSION}")
java_path="/usr/lib/jvm/java-${java_version}-openjdk-${java_path_arch_str}/bin/java"

dist_name
case "${dist}" in
    ubuntu)
        # make sure to use the right java version
        update-alternatives --set java "${java_path}"
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
