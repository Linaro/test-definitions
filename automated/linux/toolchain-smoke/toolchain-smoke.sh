#!/bin/sh -e

. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
STATIC=false

usage() {
    echo "Usage: $0 [-s ]" 1>&2
    exit 1
}

while getopts "s:" o; do
    case "$o" in
        s) STATIC=${OPTARG} ;;
        h|*) usage ;;
    esac
done

install() {
    dist_name
    # shellcheck disable=SC2154
    case "${dist}" in
      Debian|Ubuntu)
        pkgs="build-essential"
        install_deps "${pkgs}" "${SKIP_INSTALL}"
        ;;
      Fedora|CentOS)
        pkgs="gcc"
        install_deps "${pkgs}" "${SKIP_INSTALL}"
        ;;
      *) error_msg "Unsupported distribution" ;;
    esac
}

! check_root && error_msg "You need to be root to run this script."
[ -d "${OUTPUT}" ] && mv "${OUTPUT}" "${OUTPUT}_$(date +%Y%m%d%H%M%S)"
mkdir -p "${OUTPUT}"

if [ "${SKIP_INSTALL}" = "True" ] || [ "${SKIP_INSTALL}" = "true" ]; then
    info_msg "JDK package installation skipped"
else
    install
fi
FLAGS=""
if [ "${STATIC}" = "true" ] || [ "${STATIC}" = "True" ]; then
    FLAGS="-static"
fi
gcc ${FLAGS} -o hello hello.c
./hello | grep -x "Hello world"

if [ $? -eq 0 ]; then
    echo "gcc${FLAGS} pass" > "${RESULT_FILE}"
else
    echo "gcc${FLAGS} fail" > "${RESULT_FILE}"
fi
