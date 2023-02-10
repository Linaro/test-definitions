#!/bin/bash

verify_app_present () {
    app="$1"

    if docker ps | grep -q "${app}"; then
        return 0
    fi

    return 1
}

check_image () {
    image_name="$1"

    if [[ "$(docker images -q "${image_name}" 2> /dev/null)" == "" ]] ; then
        return 1
    fi

    return 0
}

get_image_sha () {
    ls /var/sota/reset-apps/apps/shellhttpd > "$(pwd)/sha.txt"
}

check_image_prune () {
    runtime="5 minutes"
    endtime=$(date -ud "$runtime" +%s)

    while true; do
        if [ "$(date -u +%s)" -ge "$endtime" ]; then
            echo "Not found"
            return 1
        elif (journalctl --no-pager -u aktualizr-lite | grep "Pruning unused docker containers"); then
            echo "Found"
            return 0
        fi
        sleep 1
   done
}

compare_sha () {
    if diff "$(pwd)/sha.txt" <(ls /var/sota/reset-apps/apps/shellhttpd) > /dev/null; then
        return 1
    fi

    return 0
}

setup_callback () {
    cp aklite-callback.sh /var/sota/
    chmod 755 /var/sota/aklite-callback.sh
    mkdir -p /etc/sota/conf.d
    cp z-99-aklite-callback.toml /etc/sota/conf.d/
    report_pass "create-aklite-callback"
    touch /var/sota/ota.signal
    touch /var/sota/ota.result
    report_pass "create-signal-files"
}

wait_for_signal () {
    SIGNAL=$(</var/sota/ota.signal)
    while [ ! "${SIGNAL}" = "check-for-update-post" ]
    do
        echo "Sleeping 1s"
        sleep 1
        cat /var/sota/ota.signal
        SIGNAL=$(</var/sota/ota.signal)
        echo "SIGNAL: ${SIGNAL}."
    done
    report_pass "update-post-received"
}

auto_register () {
    if [ -f "/var/sota/sql.db" ]; then
        echo "Device registered, skipping registration"
    else
        systemctl enable --now lmp-device-auto-register || error_fatal "Unable to register device"
    fi

    while ! systemctl is-active aktualizr-lite; do
        echo "Waiting for aktualizr-lite to start"
        sleep 1
    done
# add some delay so aklite can setup variables
    sleep 5
}
