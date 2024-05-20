#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2024 Linaro Ltd.

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
OUTPUT_FILE="${OUTPUT}/output.txt"
RESULT_FILE="${OUTPUT}/result.txt"
SKIP_INSTALL="true"

usage() {
    echo "\
    Usage: ${0} [-s True|False]
    "
}

while getopts "hs:" opt; do
    case $opt in
        s)
            SKIP_INSTALL="${OPTARG}"
            ;;
        h|*)
            usage
            exit 1
            ;;
    esac
done

create_out_dir "${OUTPUT}"

pkgs="systemd"
install_deps "${pkgs}" "${SKIP_INSTALL}"

command -v systemd-analyze
exit_on_fail "systemd-analyze not in ${PATH} or not installed"
systemd-analyze | tee "${OUTPUT_FILE}"

head -1 "${OUTPUT_FILE}" | grep -oP '\d+\.\d+s \(\w+\)' | while read -r row; do
    seconds=$(echo "${row}"| awk -F ' ' '{print $1}'|sed -e 's|s$||g')
    what=$(echo "${row}"| awk -F ' ' '{print $2}'|sed -e 's|^(||g'|sed -e 's|)$||g')
    echo "systemd-analyze-${what} pass ${seconds} seconds" | tee -a "${RESULT_FILE}"
done
