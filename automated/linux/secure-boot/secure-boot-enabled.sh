#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2022 Linaro Ltd.

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE

usage() {
  echo "Usage: $0 [-s <true|false>]" 1>&2
  exit 1
}

while getopts "s:" o; do
  case "$o" in
  s) SKIP_INSTALL="${OPTARG}" ;;
  *) usage ;;
  esac
done

if [ "${SKIP_INSTALL}" = "True" ] || [ "${SKIP_INSTALL}" = "true" ]; then
  warn_msg "Dependencies installation skipped."
else
  dist_name
  pkgs="efivar"
  # shellcheck disable=SC2154
  case "${dist}" in
  debian | ubuntu)
    install_deps "${pkgs}"
    ;;
  centos | fedora)
    install_deps "${pkgs}"
    ;;
  *)
    error_msg "Unsupported distribution!"
    ;;
  esac
fi

create_out_dir "${OUTPUT}"

trim() {
  local var="$*"
  # remove leading whitespace characters
  var="${var#"${var%%[![:space:]]*}"}"
  # remove trailing whitespace characters
  var="${var%"${var##*[![:space:]]}"}"
  printf '%s' "$var"
}

secureboot_status=$(efivar -d -n 8be4df61-93ca-11d2-aa0d-00e098032b8c-SecureBoot)
secureboot_status=$(trim "${secureboot_status}")
if [[ "${secureboot_status}" = 1 ]]; then
  report_pass "secure-boot-enabled"
else
  report_fail "secure-boot-enabled"
fi