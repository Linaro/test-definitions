#!/bin/sh

# shellcheck disable=SC1091
. ../../lib/sh-test-lib

OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE

# Default ethernet interface
INTERFACE="eth0"

usage() {
    echo "Usage: $0 [-i <ethernet-interface> -s <true|false>]" 1>&2
    exit 1
}

while getopts "s:i:" o; do
  case "$o" in
    s) SKIP_INSTALL="${OPTARG}" ;;
    # Ethernet interface
    i) INTERFACE="${OPTARG}" ;;
    *) usage ;;
  esac
done

# Test run.
! check_root && error_msg "This script must be run as root"
create_out_dir "${OUTPUT}"

pkgs="net-tools"
install_deps "${pkgs}" "${SKIP_INSTALL}"

# Print all network interface status
ip addr
# Print given network interface status
ip addr show "${INTERFACE}"

# Get IP address of a given interface
IP_ADDR=$(ip addr show "${INTERFACE}" | grep -a2 "state UP" | tail -1 | awk '{print $2}' | cut -f1 -d'/')

[ -n "${IP_ADDR}" ]
exit_on_fail "ethernet-ping-state-UP" "ethernet-ping-route"

# Get default Route IP address of a given interface
ROUTE_ADDR=$(ip route list  | grep default | awk '{print $3}' | head -1)

# Run the test
run_test_case "ping -c 5 ${ROUTE_ADDR}" "ethernet-ping-route"
