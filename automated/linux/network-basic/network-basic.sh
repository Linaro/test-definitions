#!/bin/sh -x

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
DHCLIENT="dhclient -v"
DHCLIENT_PACKAGE="isc-dhcp-client"
CURL="curl -o"
CURL_PACKAGE="curl"
export RESULT_FILE
NFS="false"

usage() {
    printf "Usage: %s \
        \n\t[-s <true|false>] \
        \n\t[-i <interface>] \
        \n\t[-n <true|false>] \
        \n\t[-c <curl -o| wget -O>] \
        \n\t[-g <curl/wget package name>] \
        \n\t[-d <dhclient -v|udhcpc>] \
        \n\t[-p <dhclient/udhcpc package name]" "$0" 1>&2
    exit 1
}

while getopts "s:i:n:c:d:p:g:" o; do
  case "$o" in
    s) SKIP_INSTALL="${OPTARG}" ;;
    i) INTERFACE="${OPTARG}" ;;
    n) NFS="${OPTARG}" ;;
    c) CURL="${OPTARG}" ;;
    g) CURL_PACKAGE="${OPTARG}" ;;
    d) DHCLIENT="${OPTARG}" ;;
    p) DHCLIENT_PACKAGE="${OPTARG}" ;;
    *) usage ;;
  esac
done

install() {
    pkgs="${CURL_PACKAGE} ${DHCLIENT_PACKAGE} net-tools"
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
GATEWAY=$(route -n | grep -m 1 "^0\.0\.0\.0.*${INTERFACE}$" | awk '{print $2}')

run "netstat -an" "print-network-statistics"
run "ip addr" "list-all-network-interfaces"
run "route" "print-routing-tables"
run "ip link set lo up" "ip-link-loopback-up"
run "route" "route-dump-after-ip-link-loopback-up"
run "ip link set ${INTERFACE} up" "ip-link-interface-up"
# NFS mounted filesystem hangs when interface set down
# so skip "ip link set <interface> down" when NFS is not false

if [ "${NFS}" = "false" ] || [ "${NFS}" = "False" ]; then
    run "ip link set ${INTERFACE} down" "ip-link-interface-down"
else
    info_msg "Skipping ip link set ${INTERFACE} down on NFS mounted file systems"
    report_skip "ip-link-interface-down"
fi

dist_name
# shellcheck disable=SC2154
case "${dist}" in
    centos|fedora)
       # dhclient exits with non-zero when it is already running.
       # Kill it first for the next dhclient test.
       # shellcheck disable=SC2086
       pkill ${DHCLIENT} || true
       # It takes time to kill dhclient.
       sleep 10
       ;;
esac

run "${DHCLIENT} ${INTERFACE}" "Dynamic-Host-Configuration-Protocol-Client-dhclient-v"
run "route" "print-routing-tables-after-dhclient-request"
run "ping -c 5 ${GATEWAY}" "ping-gateway"
run "${CURL} ${OUTPUT}/curl_big_video.avi http://samplemedia.linaro.org/MPEG4/big_buck_bunny_480p_MPEG4_MP3_25fps_1600K_short.AVI" "download-a-file"

# exit with return code 0 to help LAVA parse results
exit 0
