#!/bin/bash
# shellcheck disable=SC1091
. ../../lib/sh-test-lib
. ./prune-lib.sh

OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE

TOKEN=$(cat /etc/lmp-device-register-token)
DEVICE_NAME=$(cat /etc/hostname)
API_DATA='{ "reason": "Prune Test", "files":
[{"name":"z-50-fioctl.toml","on-changed":["/usr/share/fioconfig/handlers/aktualizr-toml-update"],"unencrypted":true,"value":"\n[pacman]\n compose_apps = \"\"\n"}]}'
FACTORY=$(grep -w "LMP_FACTORY" /etc/os-release | cut -d'=' -f2 | sed 's/\"//g')


! check_root && error_msg "You need to be root to run this script."
create_out_dir "${OUTPUT}"

setup_callback

auto_register

while ! docker ps -a | grep "shellhttpd"; do
    echo "waiting for container"
    sleep 1
done

get_image_sha

curl --data "$API_DATA" -H "Content-Type: application/json" -H "OSF-TOKEN: $TOKEN" -X PATCH https://api.foundries.io/ota/devices/"$DEVICE_NAME"/config/?factory="$FACTORY"

wait_for_signal

if check_image_prune; then
    report_pass "disable-prune"
else
    report_fail "disable-prune"
fi

if check_image shellhttpd; then
    report_fail "image-removed"
else
    report_pass "image-removed"
fi

rm "$(pwd)/sha.txt"
