#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2021 Foundries.io Ltd.

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE
OSTREE_HASH=""
SKIP_INSTALL="false"

usage() {
    echo "\
    Usage: $0
             [-m <ostree hash>]
             [-s <true|false>]
             [-h]

    -m <ostree hash>
        This is the hash expected to be found from OSTree
    -s <true|false>
        Skip installing dependencies
    -h
        Display this message
    "
}

while getopts "s:m:h" opts; do
    case "$opts" in
        m) OSTREE_HASH="${OPTARG}";;
        s) SKIP_INSTALL="${OPTARG}" ;;
        h|*) usage ; exit 1 ;;
    esac
done

if [ "${SKIP_INSTALL}" = "true" ] || [ "${SKIP_INSTALL}" = "True" ]; then
    info_msg "ostree installation skipped"
else
    install_deps "ostree"
fi

create_out_dir "${OUTPUT}"
if [ -z "${OSTREE_HASH}" ]; then
    warn_msg "OSTREE_HASH empty. Skipping"
    report_skip "ostree-hash"
fi

ostree admin status
if (ostree admin status | grep "${OSTREE_HASH}"); then
    report_pass "ostree-hash"
else
    report_fail "ostree-hash"
fi
