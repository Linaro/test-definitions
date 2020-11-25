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
    a) TVM_WHEEL="${OPTARG}" ;;
    t) TVM_BENCH="${OPTARG}" ;;
    s) SKIP_INSTALL="{$OPTARG}" ;;
    *) usage ;;
  esac
done
#    f) TF_BENCH="${OPTARG}" ;;
#    d) TVM_INSTALL="${OPTARG}" ;;
! check_root && error_msg "You need to be root to run this script."
create_out_dir "${OUTPUT}"

pkgs="wget ntp python3 python3-pip git

install_deps "${pkgs}" "${SKIP_INSTALL}"

git clone "${TVM_BENCH}"
wget "${TVM_WHEEL}"
pip3 install "tlcpack*.whl"
cd tvm-bench && python3 mobilenet-v1.0.5-acl-float.py
