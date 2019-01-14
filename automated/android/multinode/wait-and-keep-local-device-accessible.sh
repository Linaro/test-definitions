#!/bin/sh

set -o nounset

# Internal configuration
RESULT=
MY_ROOT_DIR="$(dirname "$0")"
MY_AUTOMATED_DIR="${MY_ROOT_DIR}/../../../automated"

# Configuration gathered from the environment
ADB_PORT=${ADB_PORT:-5555}
BOOT_TIMEOUT_SECS=${BOOT_TIMEOUT_SECS:-900}
NETWORK_TIMEOUT_SECS=${NETWORK_TIMEOUT_SECS:-300}
ADB_TCPIP_ATTEMPTS=${ADB_TCPIP_ATTEMPTS:-5}
ADB_CONNECT_TEST_TIMEOUT_SECS=${ADB_CONNECT_TEST_TIMEOUT_SECS:-60}
ANDROID_ENABLE_WIFI=${ANDROID_ENABLE_WIFI:-true}
USERDATA_IMAGE_FILE=${USERDATA_IMAGE_FILE:-""}

# shellcheck source=automated/lib/sh-test-lib
. "${MY_AUTOMATED_DIR}/lib/sh-test-lib"
# shellcheck source=automated/lib/android-test-lib
. "${MY_AUTOMATED_DIR}/lib/android-test-lib"
# shellcheck source=automated/lib/android-multinode-test-lib
. "${MY_AUTOMATED_DIR}/lib/android-multinode-test-lib"


reconnect_device() {
    timeout 10 fastboot reboot || true

    # shellcheck disable=SC2039
    local ret_val=0
    sh -c ". ${MY_AUTOMATED_DIR}/lib/sh-test-lib \
        && . ${MY_AUTOMATED_DIR}/lib/android-test-lib \
        && wait_boot_completed \"${BOOT_TIMEOUT_SECS}\"" || ret_val=$?

    if [ "${ret_val}" -ne 0 ]; then
        RESULT=false
        warn_msg "Reconnect attempt failed: target did not boot up or is not \
accessible."
        return
    fi

    if [ "${ANDROID_ENABLE_WIFI}" = "true" ]; then
        "${MY_AUTOMATED_DIR}/lib/android_ui_wifi.py" -a set_wifi_state on \
            || ret_val=$?
        if [ "${ret_val}" -ne 0 ]; then
            warn_msg "Cannot ensure that Wi-Fi is enabled in the device \
settings; UI automation failed."
        fi
    fi

    ret_val=0
    sh -c ". ${MY_AUTOMATED_DIR}/lib/sh-test-lib \
        && . ${MY_AUTOMATED_DIR}/lib/android-test-lib \
        && . ${MY_AUTOMATED_DIR}/lib/android-multinode-test-lib \
        && wait_network_connected \"${NETWORK_TIMEOUT_SECS}\" \
        && open_adb_tcpip_on_local_device \
            \"${ADB_TCPIP_ATTEMPTS}\" \"${ADB_CONNECT_TEST_TIMEOUT_SECS}\" \
            \"${ADB_PORT}\"" \
        || ret_val=$?

    if [ "${ret_val}" -ne 0 ]; then
        RESULT=false
        warn_msg "Reconnect attempt failed."
    fi
}

userdata_reset() {
    if [ -z "${USERDATA_IMAGE_FILE}" ]; then
        warn_msg "Skipping userdata_reset; no image file provided."
        return
    fi
    if [ ! -f "${USERDATA_IMAGE_FILE}" ]; then
        warn_msg "Skipping userdata_reset; image file not found: \
${USERDATA_IMAGE_FILE}."
        return
    fi
    # shellcheck disable=SC2039
    local previousResult="${RESULT}"
    RESULT=false
    if ! timeout "${ADB_CONNECT_TEST_TIMEOUT_SECS}" adb reboot bootloader; then
        warn_msg "Reboot into bootloader failed."
        return
    fi
    if ! fastboot flash userdata "${USERDATA_IMAGE_FILE}"; then
        warn_msg "Flashing userdata image failed."
        return
    fi
    if ! timeout 10 fastboot reboot; then
        warn_msg "Device did not reboot from fastboot as expected."
        return
    fi
    RESULT="${previousResult}"
}


lava-test-set start keepAlive

iteration=1

while true; do
    lava-wait "master-sync-$(lava-self)-${iteration}"

    command="$(sed -n '/.*command=.\+/s/.*command=//p' \
        /tmp/lava_multi_node_cache.txt)"

    RESULT="pass"

    case "${command}" in
    continue)
        ;;
    release)
        break
        ;;
    reconnect)
        info_msg "Reconnect requested by master."
        adb kill-server || true
        adb devices || true
        reconnect_device
        ;;
    userdata_reset)
        info_msg "Userdata reset requested by master."
        userdata_reset
        reconnect_device
        ;;
    *)
        lava-test-raise "Script error. Unexpected message from master to \
worker, command=${command}"
    esac

    lava-send "worker-sync-$(lava-self)-${iteration}" "result=${RESULT}"

    iteration="$(( iteration + 1))"
done

info_msg "master released the device."
lava-test-set stop
