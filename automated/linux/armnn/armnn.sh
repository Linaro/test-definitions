#!/bin/bash

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
OUTPUT_FILE="${OUTPUT}/results.txt"
PYTEST="false"
ARMNN_TARBALL="https://snapshots.linaro.org/components/armnn/latest/armnn-full.tar.xz"
SKIP_INSTALL="false"
TEST_DIR="/tmp/armnn"
UNIT_TESTS="true"

usage() {
  echo "Usage: $0 [-s <true|false>]
                  [-a <armnn-tarball>]
                  [-t <true|false>]
                  [-p <true|false>]
                  [-d <testing-dir-location>]" 1>&2
  exit 1
}

while getopts "s:a:t:p:d:" o; do
  case "$o" in
    s) SKIP_INSTALL="${OPTARG}" ;;
    a) ARMNN_TARBALL="${OPTARG}" ;;
    t) UNIT_TESTS="${OPTARG}" ;;
    p) PYTEST="${OPTARG}" ;;
    d) TEST_DIR="${OPTARG}" ;;
    *) usage ;;
  esac
done

pkgs="ntp wget gcc g++ systemd"
if [ "${PYTEST}" = true ]; then
  pkgs2="python3-dev python3-pip"
fi
dhclient
install_deps "${pkgs}" "${SKIP_INSTALL}"

systemctl restart ntp > /dev/null 2>&1
systemctl enable ntp > /dev/null 2>&1
systemctl stop hostapd > /dev/null 2>&1


create_out_dir "${OUTPUT}"

if [ "${PYTEST}" = true ]; then
  install_deps "${pkgs2}" "${SKIP_INSTALL}"
  pip3 install pytest
fi

if [ "${SKIP_INSTALL}" = false ] && [ -n "${ARMNN_TARBALL}" ]; then
  mkdir -p "${TEST_DIR}"
  pushd "${TEST_DIR}" || exit
  wget --no-check-certificate --quiet -O armnn.tar.xz "${ARMNN_TARBALL}"
  tar xf armnn.tar.xz
  export BASEDIR="${TEST_DIR}"/home/buildslave/workspace/armnn-ci-build
  pushd "${BASEDIR}"/build || exit
  LD_LIBRARY_PATH=$(pwd)
  export LD_LIBRARY_PATH
  PATH="$(pwd):$PATH"
  chmod a+x UnitTests
  popd || exit
  popd || exit
fi

if [ "${UNIT_TESTS}" = true ]; then
  cmd="UnitTests"
  if command -v "${cmd}"; then
    UnitTests -- --dynamic-backend-build-dir "${BASEDIR}"/build 2>&1 | tee UnitTestResult.txt
    if grep 'No errors detected' UnitTestResult.txt -n; then
      echo 'ArmNN-Unit-Tests pass' >> "${OUTPUT_FILE}"
    else
      echo 'ArmNN-Unit-Tests fail' >> "${OUTPUT_FILE}"
    fi
  else
    echo "Can't find ${cmd}"
  fi
fi

if [ "${SKIP_INSTALL}" = false ] && [ "${PYTEST}" = true ]; then
  python3 "${BASEDIR}"/python/pyarmnn/scripts/download_test_resources.py
  export ARMNN_LIB="${BASEDIR}"/build
  export ARMNN_INCLUDE="${BASEDIR}"/build/include
  pip3 install "${BASEDIR}"/build/python/pyarmnn/dist/pyarmnn*.gz
fi

if [ "${PYTEST}" = true ]; then
  python3 -m pytest "${BASEDIR}"/python/pyarmnn/test/ -v
fi
