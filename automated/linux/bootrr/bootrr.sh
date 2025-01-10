#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2025 Qualcomm Inc.

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
BOARD=""
REPOSITORY="https://github.com/linux-msm/bootrr"
SKIP_INSTALL="true"

usage() {
    echo "Usage: $0 [-b <board>] [-r <bootrr repository url>] [-s <true|false>]" 1>&2
    exit 1
}

while getopts "b:r:s:" o; do
  case "$o" in
    b) BOARD="${OPTARG}" ;;
    r) REPOSITORY="${OPTARG}" ;;
    s) SKIP_INSTALL="${OPTARG}" ;;
    *) usage ;;
  esac
done

install() {
    install_deps git "${SKIP_INSTALL}"
    git clone "${REPOSITORY}" bootrr
    cd bootrr || error_msg "bootrr cloning failed"
    make DESTDIR=/ install
}

! check_root && error_msg "This script must be run as root"

if [ "${SKIP_INSTALL}" = "false" ] ||  [ "${SKIP_INSTALL}" = "False" ] || [ "${SKIP_INSTALL}" = "FALSE" ]; then
    install
fi

if [ -z "${BOARD}" ]; then
    # bootrr tests are executed based on DTB
    bootrr
else
    # run tests for board that might not be compatible
    BOOTRR_DIR="/usr/libexec/bootrr"
    PATH="${BOOTRR_DIR}/helpers:${PATH}"
    if [ -x "${BOOTRR_DIR}/boards/${BOARD}" ]; then
        ${BOOTRR_DIR}/boards/"${BOARD}"
    fi
fi
