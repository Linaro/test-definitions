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

install_docker() {
    which docker && return

    dist_name
    # shellcheck disable=SC2154
    case "${dist}" in
        debian|ubuntu|fedora|centos)
            install_deps curl
            curl -fsSL get.docker.com -o get-docker.sh
            sh get-docker.sh
            ;;
        *)
            warn_msg "No package installation support on ${dist}"
            error_msg "And docker not pre-installed, exiting..."
            ;;
    esac
}

skip_list="start-docker-service run-docker-image"
install_docker
exit_on_fail "install-docker" "${skip_list}"

skip_list="run-docker-image"
systemctl start docker
exit_on_fail "start-docker-service" "${skip_list}"

docker run -it "${IMAGE}" /bin/echo "Hello Docker"
check_return "run-docker-image"
