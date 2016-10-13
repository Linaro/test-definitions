#!/bin/sh

. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
INTERFACE="eth0"
GATEWAY="10.0.0.1"

usage() {
    echo "Usage: $0 [-s <true|false>] [-i <eth0>] [-g <10.0.0.1>]" 1>&2
    exit 1
}

while getopts "s:i:g:" o; do
  case "$o" in
    s) SKIP_INSTALL="${OPTARG}" ;;
    i) INTERFACE="${OPTARG}" ;;
    g) GATEWAY="${OPTARG}" ;;
    *) usage ;;
  esac
done

install() {
    pkgs="curl"
    install_deps "${pkgs}" "${SKIP_INSTALL}"
}

run() {
    local test="$1"
    test_case_id="$2"
    echo
    info_msg "Running ${test_case_id} test..."
    info_msg "Running ${test} test..."
    eval "${test}"
    check_return "${test_case_id}"
}

# Test run.
[ -d "${OUTPUT}" ] && mv "${OUTPUT}" "${OUTPUT}_$(date +%Y%m%d%H%M%S)"
mkdir -p "${OUTPUT}"

install
run "netstat -an" "print-network-statistics"
run "ip addr" "list-all-network-interfaces"
run "route" "print-routing-tables"
run "ifconfig lo up" "ifconfig-loopback-up"
run "route" "route-dump-after-ifconfig-loopback-up"
run "ifconfig ${INTERFACE} up" "ifconfig-interface-${INTERFACE}-up"
run "ifconfig ${INTERFACE} down" "ifconfig-interface-${INTERFACE}-down"
run "dhclient -v ${INTERFACE}" "Dynamic-Host-Configuration-Protocol-Client-dhclient-v-${INTERFACE}"
run "route" "print-routing-tables-after-dhclient-request"
run "ping -c 5 ${GATEWAY}" "ping-gateway-${GATEWAY}"
run "curl http://samplemedia.linaro.org/MPEG4/big_buck_bunny_720p_MPEG4_MP3_25fps_3300K.AVI -o curl_big_video.avi" "download-a-file"
