#!/bin/bash

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE
IMAGE="alpine:latest"
SKIP_INSTALL="True"

usage() {
    echo "$0 [-i <image>] [-s true|false]" 1>&2
    exit 1
}

while getopts "i:s:h" o; do
    case "$o" in
        i) IMAGE="${OPTARG}" ;;
        s) SKIP_INSTALL="${OPTARG}";;
        h|*) usage ;;
    esac
done

! check_root && error_msg "You need to be root to run this script."
create_out_dir "${OUTPUT}"
cd "${OUTPUT}" || exit

install_docker() {
    command -v docker && return

    dist_name
    # shellcheck disable=SC2154
    case "${dist}" in
        debian|ubuntu|fedora|centos)
            install_deps curl jq
            curl -fsSL get.docker.com -o get-docker.sh
            sh get-docker.sh
            ;;
        *)
            warn_msg "No package installation support on ${dist}"
            error_msg "And docker not pre-installed, exiting..."
            ;;
    esac
}

if [ "${SKIP_INSTALL}" = "True" ] || [ "${SKIP_INSTALL}" = "true" ]; then
    info_msg "Installation skipped"
else
    install_docker
fi
# verify that docker is available
skip_list="docker-network-list docker-start-container docker-network-inspect docker-network-bridge ping-container-test docker-kill-container docker-ping-localhost-host-network"
docker --version
exit_on_fail "docker-version" "${skip_list}"

# check if bridge network is present
skip_list="docker-start-container docker-network-inspect docker-network-bridge ping-container-test docker-kill-container docker-ping-localhost-host-network"
docker network ls -f name=bridge | grep bridge
exit_on_fail "docker-network-list" "${skip_list}"

# start simple alpine container
skip_list="docker-network-inspect docker-network-bridge ping-container-test docker-kill-container docker-ping-localhost-host-network"
docker run --name ping_test_container --rm -d "${IMAGE}" /bin/sleep 90
exit_on_fail "docker-start-container" "${skip_list}"

# container should join bridge network
skip_list="docker-network-bridge ping-container-test docker-kill-container docker-ping-localhost-host-network"
DOCKER_INSPECT=$(docker network inspect bridge)
exit_on_fail "docker-network-inspect" "${skip_list}"

echo "$DOCKER_INSPECT" | jq '.[0]["Containers"][]'
IP_ADDR=$(echo "$DOCKER_INSPECT" | jq '.[0]["Containers"][] | select(.Name=="ping_test_container") | .IPv4Address | split("/")[0]')
echo "${IP_ADDR}"
if [ -n "$IP_ADDR" ]; then
    report_pass "docker-network-bridge"
    eval "ping -c4 $IP_ADDR"
    check_return "ping-container-test"
else
    report_fail "docker-network-bridge"
    report_skip "ping-container-test"
fi

docker kill ping_test_container
check_return "docker-kill-container"

# IPv4 try pinging localhost from container with host networking
docker run --name ping_localhost_host_network --rm -d "${IMAGE}" ping -4 -c 4 localhost
check_return "docker-ping-localhost-host-network"

exit 0
