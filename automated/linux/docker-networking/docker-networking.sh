#!/bin/bash

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE
IMAGE="alpine:latest"
SKIP_INSTALL="True"
NETWORK_TYPE="bridge"
HOST_INTERFACE="eth0"

usage() {
    echo "$0 [-i <image>] [-n <bridge|host|none>] [-s true|false] [-b eth0]" 1>&2
    echo "    -n option can be a combination of bridge, host and none." 1>&2
    echo "       Options should be space separated." 1>&2
    echo "       In case there are more than one, all tests will be executed." 1>&2
    exit 1
}

while getopts "i:s:n:b:h" o; do
    case "$o" in
        i) IMAGE="${OPTARG}" ;;
        s) SKIP_INSTALL="${OPTARG}";;
        n) NETWORK_TYPE="${OPTARG}";;
        b) HOST_INTERFACE="${OPTARG}";;
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

remove_one_from_skiplist() {
    echo "$1" | cut -f2- -d" "
}

if [ "${SKIP_INSTALL}" = "True" ] || [ "${SKIP_INSTALL}" = "true" ]; then
    info_msg "Installation skipped"
else
    install_docker
fi

HOST_IP=$(ip addr show dev "${HOST_INTERFACE}" | grep "inet " | awk '{ print $2 }' | awk -F "/" '{print $1}')

# verify that docker is available
for NETWORK in ${NETWORK_TYPE}; do
    skip_list="${skip_list} docker-network-list-${NETWORK} docker-start-container-${NETWORK} docker-network-inspect-${NETWORK} docker-network-${NETWORK} ping-container-test-${NETWORK} docker-kill-container-${NETWORK} docker-ping-host-network-${NETWORK}"
done
docker --version
exit_on_fail "docker-version" "${skip_list}"

for NETWORK in ${NETWORK_TYPE}; do
    # check if bridge network is present
    skip_list=$(remove_one_from_skiplist "${skip_list}")
    docker network ls -f name="${NETWORK}" | grep "${NETWORK}"
    exit_on_fail "docker-network-list" "${skip_list}"

    # start simple alpine container
    skip_list=$(remove_one_from_skiplist "${skip_list}")
    docker run --name ping_test_container --network "${NETWORK}" --rm -d "${IMAGE}" /bin/sleep 90
    exit_on_fail "docker-start-container" "${skip_list}"

    # container should join NETWORK network
    skip_list=$(remove_one_from_skiplist "${skip_list}")
    DOCKER_INSPECT=$(docker network inspect "${NETWORK}")
    exit_on_fail "docker-network-inspect-${NETWORK}" "${skip_list}"

    skip_list=$(remove_one_from_skiplist "${skip_list}")
    if [ "${NETWORK}" = "bridge" ]; then
        echo "$DOCKER_INSPECT" | jq '.[0]["Containers"][]'
        IP_ADDR=$(echo "$DOCKER_INSPECT" | jq '.[0]["Containers"][] | select(.Name=="ping_test_container") | .IPv4Address | split("/")[0]')
        echo "${IP_ADDR}"
        if [ -n "$IP_ADDR" ]; then
            report_pass "docker-network-${NETWORK}"
            eval "ping -c4 $IP_ADDR"
            skip_list=$(remove_one_from_skiplist "${skip_list}")
            check_return "ping-container-test-${NETWORK}"
        else
            report_fail "docker-network-${NETWORK}"
            skip_list=$(remove_one_from_skiplist "${skip_list}")
            report_skip "ping-container-test-${NETWORK}"
        fi
    else
        report_pass "docker-network-${NETWORK}"
        skip_list=$(remove_one_from_skiplist "${skip_list}")
        report_skip "ping-container-test-${NETWORK}"
    fi
    skip_list=$(remove_one_from_skiplist "${skip_list}")
    docker kill ping_test_container
    check_return "docker-kill-container-${NETWORK}"

    skip_list=$(remove_one_from_skiplist "${skip_list}")
    if [ -n "${HOST_IP}" ]; then
        xfail=""
        if [ "${NETWORK}" = none ]; then
            # ping should fail with disabled networking
            xfail="xfail"
        fi
        docker run --name ping_localhost_host_network --network "${NETWORK}" --rm "${IMAGE}" ping -4 -c 4 "${HOST_IP}"
        check_return "docker-ping-host-network-${NETWORK}" "${xfail}"
    else
        report_skip "docker-ping-host-network-${NETWORK}"
    fi
done

exit 0
