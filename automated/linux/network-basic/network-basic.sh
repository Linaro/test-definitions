#!/bin/sh -x

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE

usage() {
    echo "Usage: $0 [-s <true|false>] [-i <interface>]" 1>&2
    exit 1
}

while getopts "s:i:" o; do
  case "$o" in
    s) SKIP_INSTALL="${OPTARG}" ;;
    i) INTERFACE="${OPTARG}" ;;
    *) usage ;;
  esac
done

install() {
    pkgs="curl net-tools"
    install_deps "${pkgs}" "${SKIP_INSTALL}"
}

run() {
    test_case="$1"
    test_case_id="$2"
    echo
    info_msg "Running ${test_case_id} test..."
    info_msg "Running ${test_case} test..."
    eval "${test_case}"
    check_return "${test_case_id}"
}

# Test run.
create_out_dir "${OUTPUT}"

install

# When not specified, test the default interface.
test -z "${INTERFACE}" && INTERFACE=$(route | grep -m 1 "^default" | awk '{print $NF}')
# Get Route Gateway IP address of a given interface.
GATEWAY=$(route | grep -m 1 "^default.*${INTERFACE}$" | awk '{print $2}')

run "netstat -an" "print-network-statistics"
run "ip addr" "list-all-network-interfaces"
run "route" "print-routing-tables"
run "ip link set lo up" "ip-link-loopback-up"
run "route" "route-dump-after-ip-link-loopback-up"
run "ip link set ${INTERFACE} up" "ip-link-interface-up"
run "ip link set ${INTERFACE} down" "ip-link-interface-down"
run "dhclient -v ${INTERFACE}" "Dynamic-Host-Configuration-Protocol-Client-dhclient-v"
run "route" "print-routing-tables-after-dhclient-request"
run "ping -c 5 ${GATEWAY}" "ping-gateway"
run "curl http://samplemedia.linaro.org/MPEG4/big_buck_bunny_720p_MPEG4_MP3_25fps_3300K.AVI -o curl_big_video.avi" "download-a-file"
