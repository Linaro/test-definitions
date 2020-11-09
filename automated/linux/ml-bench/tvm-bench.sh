#!/bin/sh

# shellcheck disable=SC1091

. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"

usage() {
    echo "Usage: $0 [-s <true|false>]" 1>&2
    exit 1
}

while getopts "s:a:d:" o; do
  case "$o" in
#   t) TVM_BENCH="${OPTARG}" ;;
#    f) TF_BENCH="${OPTARG}" ;;
#    d) TVM_INSTALL="${OPTARG}" ;;
    s) SKIP_INSTALL="{$OPTARG}" ;;
    *) usage ;;
  esac
done

! check_root && error_msg "You need to be root to run this script."
create_out_dir "${OUTPUT}"

pkgs="wget ntp python3 python3-pip git

install_deps "${pkgs}" "${SKIP_INSTALL}"

# git clone https://github.com/tom-gall/tvm-bench.git
# pip3 install "${TVM_INSTALL}"
# python3 mobilenet etc.
