#!/bin/sh -e

. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE
STATIC=false

usage() {
    echo "Usage: $0 [-s <true|flase>] [-t <true|flase>]" 1>&2
    exit 1
}

while getopts "s:t:h" o; do
    case "$o" in
        t) STATIC=${OPTARG} ;;
        s) SKIP_INSTALL="${OPTARG}" ;;
        h|*) usage ;;
    esac
done

install() {
    dist_name
    # shellcheck disable=SC2154
    case "${dist}" in
      Debian|Ubuntu)
        pkgs="build-essential"
        install_deps "${pkgs}"
        ;;
      Fedora|CentOS)
        pkgs="gcc glibc-static"
        install_deps "${pkgs}"
        ;;
      *) error_msg "Unsupported distribution" ;;
    esac
}

! check_root && error_msg "You need to be root to run this script."
[ -d "${OUTPUT}" ] && mv "${OUTPUT}" "${OUTPUT}_$(date +%Y%m%d%H%M%S)"
mkdir -p "${OUTPUT}"

if [ "${SKIP_INSTALL}" = "True" ] || [ "${SKIP_INSTALL}" = "true" ]; then
    info_msg "gcc package installation skipped"
else
    install
fi
FLAGS=""
if [ "${STATIC}" = "true" ] || [ "${STATIC}" = "True" ]; then
    FLAGS="-static"
fi

skip_list="execute_binary"
command="gcc ${FLAGS} -o hello hello.c"
run_test_case "${command}" "gcc${FLAGS}" "${skip_list}"

command="./hello | grep -x 'Hello world'"
# skip_list is used as test case name to avoid typing mistakes
run_test_case "${command}" "${skip_list}"
