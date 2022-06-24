#!/bin/sh -e

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE

! check_root && error_msg "You need to be root to run this script."
create_out_dir "${OUTPUT}"
cd "${OUTPUT}" || exit

#check /run/secrets exists, create if not
[ -d /run/secrets ] || mkdir /run/secrets

#file content to be overwritten in test
echo "endpoint=217.44.46.222:5186" > /run/secrets/wireguard-server
echo "server_address=10.42.42.1" >> /run/secrets/wireguard-server
echo "pubkey=2Ay+p6qpERs50Wi2tzfZECNSV2gqU8hw36wemN63a2Q=" >> /run/secrets/wireguard-server

wgServerFile="/run/secrets/wireguard-server"

m1=$(md5sum "$wgServerFile")

#auto register
systemctl enable --now lmp-device-auto-register || error_fatal "Unable to register device"

while ! systemctl is-active fioconfig; do
    echo "Waiting for fioconfig to start"
    sleep 1
done

m2=$(md5sum "$wgServerFile")

if [ "$m1" !=  "$m2" ] ; then
    echo "Wireguard-server updated." >& 2
    report_pass "wg-pk-test"
else
    report_fail "wg-pk-test"
    exit 1
fi
