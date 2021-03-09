#!/bin/bash

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
OUTPUT_FILE="${OUTPUT}/results.txt"
SKIP_INSTALL="false"
TVM_TARBALL="http://snapshots.linaro.org/components/tvm/latest/tvm.tar.xz"
TEST_DIR="/tmp/tvm-dir"
TVM_HOME="${TEST_DIR}"/tvm

usage() {
  echo "Usage: $0 [-s <true|false>]
                  [-t <tvm-tarball>]
                  [-d <testing-dir-location>]
                  [-e <tvm-home-location>]" 1>&2
  exit 1
}

while getopts "s:t:d:e:h:" o; do
  case "$o" in
    s) SKIP_INSTALL="${OPTARG}" ;;
    t) TVM_TARBALL="${OPTARG}" ;;
    d) TEST_DIR="${OPTARG}" ;;
    e) TVM_HOME="${OPTARG}" ;;
    h|*) usage ;;
  esac
done

pkgs="ntp wget systemd"
# Package installs must be split in two steps due to installs failing from system clock being wrong.
pkgs2="llvm"

dhclient
install_deps "${pkgs}" "${SKIP_INSTALL}"
# NTP restart is necessary to get the system clock back in order currently on some board images such as db845c
systemctl restart ntp > /dev/null 2>&1
systemctl enable ntp > /dev/null 2>&1
systemctl stop hostapd > /dev/null 2>&1

create_out_dir "${OUTPUT}"

install_deps "${pkgs2}" "${SKIP_INSTALL}"

if [ "${SKIP_INSTALL}" = false ] && [ -n "${TVM_TARBALL}" ]; then
  mkdir -p "${TEST_DIR}"
  pushd "${TEST_DIR}" || exit
  wget --no-check-certificate --quiet -O tvm.tar.xz "${TVM_TARBALL}"
  tar xf tvm.tar.xz
  export PYTHONPATH="${TVM_HOME}"/python:"${PYTHONPATH}"
  sed -i -e 's+/home/buildslave/workspace/tvm-ci-build/+/tmp/tvm-dir/+' "${TVM_HOME}"/build/CMakeCache.txt
  sed -i -e 's+/home/buildslave/workspace/tvm-ci-build/+/tmp/tvm-dir/+' "${TVM_HOME}"/googletest/build/CMakeCache.txt
  pushd "${TVM_HOME}"/build || exit
  LD_LIBRARY_PATH="${LD_LIBRARY_PATH}":$(pwd)
  export LD_LIBRARY_PATH
  pushd "${TVM_HOME}" || exit
  source tests/scripts/setup-pytest-env.sh
  LD_LIBRARY_PATH="lib:${LD_LIBRARY_PATH:-}"
  export LD_LIBRARY_PATH
  VTA_HW_PATH=$(pwd)/3rdparty/vta-hw
  export VTA_HW_PATH
  export TVM_BIND_THREADS=0
  export OMP_NUM_THREADS=1
  popd || exit
  popd || exit
  popd || exit
fi

pushd "${TVM_HOME}" || exit
for test in build/*_test; do
  ./"$test" 2>&1 | tee "$test".txt
  if grep 'PASSED' "$test".txt -n ; then
    echo "$test  pass" >> "${OUTPUT_FILE}"
  else
    echo "$test  fail" >> "${OUTPUT_FILE}"
  fi
done
popd || exit
