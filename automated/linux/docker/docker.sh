#!/bin/sh

# shellcheck disable=SC1091
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
create_out_dir "${OUTPUT}"
cd "${OUTPUT}" || exit

skip_list="start-docker-service run-docker-image"
curl -fsSL get.docker.com -o get-docker.sh
sh get-docker.sh
exit_on_fail "install-docker" "${skip_list}"

skip_list="run-docker-image"
systemctl start docker
exit_on_fail "start-docker-service" "${skip_list}"

docker run -it "${IMAGE}" /bin/echo "Hello Docker"
check_return "run-docker-image"
