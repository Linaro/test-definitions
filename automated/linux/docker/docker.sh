#!/bin/sh

. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE
IMAGE="aarch64/ubuntu"

usage() {
    echo "$0 [-i <image>]" 1>&2
    exit 1
}

while getopts "i:h" o; do
    case "$o" in
        i) IMAGE="${OPTARG}" ;;
        h|*) usage ;;
    esac
done

! check_root && error_msg "You need to be root to run this script."
[ -d "${OUTPUT}" ] && mv "${OUTPUT}" "${OUTPUT}_$(date +%Y%m%d%H%M%S)"
mkdir -p "${OUTPUT}"

skip_list="start-docker-service run-docker-image"
install_deps "docker-engine"
exit_on_fail "install-docker-engine" "${skip_list}"

skip_list="run-docker-image"
systemctl start docker
exit_on_fail "start-docker-service" "${skip_list}"

docker run -it "${IMAGE}" /bin/echo "Hello Docker"
check_return "run-docker-image"
