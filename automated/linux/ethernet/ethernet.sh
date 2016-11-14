#!/bin/sh

# shellcheck disable=SC1091
. ../../lib/sh-test-lib

OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE

# Default ethernet interface
INTERFACE="eth0"

usage() {
    echo "Usage: $0 [-i <eth0|wlan0>]" 1>&2
    exit 1
}

while getopts "i:" o; do
  case "$o" in
    # Ethernet interface
    i) INTERFACE="${OPTARG}" ;;
    *) usage ;;
  esac
done

# Test run.
! check_root && error_msg "This script must be run as root"
[ -d "${OUTPUT}" ] && mv "${OUTPUT}" "${OUTPUT}_$(date +%Y%m%d%H%M%S)"
mkdir -p "${OUTPUT}"

testcase="ethernet-ip-addr-${INTERFACE}"

# Print all network interface status
ip addr
# Print given network interface status
ip addr show "${INTERFACE}"

# Get IP address of given interface
IP_ADDR=$(ip addr show "${INTERFACE}" | grep "${INTERFACE}" | tail -1 | awk '{print $2}' | cut -f1 -d'/')

# Validate IP address by ping
testcase_cmd="ping ${IP_ADDR} -c 5"

# Run the test
run_test_case "${testcase_cmd}" "${testcase}"
