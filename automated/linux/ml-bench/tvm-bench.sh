#!/bin/sh

# shellcheck disable=SC1091

. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"

usage() {
    echo "Usage: $0 [-s <true|false>]" 1>&2
    exit 1
}

#default values
TVM_WHEEL='https://github.com/tlc-pack/tlcpack/releases/download/v0.7.dev1/tlcpack-0.7.dev1-cp38-cp38-manylinux2010_x86_64.whl'
TVM_BENCH='https://github.com/tom-gall/tvm-bench.git'
SKIP_INSTALL=false

while getopts "s:a:t:" o; do
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

pkgs="wget ntp python3 python3-pip git"
install_deps "${pkgs}" "${SKIP_INSTALL}"
if [ -n "${TVM_BENCH}" ]; then
    git clone "${TVM_BENCH}"
        if [ -n "${TVM_WHEEL}" ]; then
            wget "${TVM_WHEEL}"
            pip3 install "tlcpack*.whl"
        fi
    cd tvm-bench || exit
    python3 mobilenet-v1.0.5-acl-float.py
fi
