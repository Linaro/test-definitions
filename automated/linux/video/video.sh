#!/bin/sh

# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2024 Qualcomm Inc.

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE
REFERENCE_IMAGE=""
REFERENCE_IMAGE_USER=""
REFERENCE_IMAGE_PASSWORD=""
REFERENCE_IMAGE_TOKEN=""
THRESHOLD=0.99
DEVICE="/dev/video0"
IMAGE=""

usage() {
    echo "\
    Usage: $0 [-p <pkcs11-tool>] [-t <true|false>] [-s <true|false>] [-l <true|false>]

    -r <reference image>
    -t <threshold>
    -d <device>
    -u <reference download username>
    -p <reference download password>
    -T <reference download token>
    -i <image>
    "
}

while getopts "p:t:d:u:r:T:i:h" opts; do
    case "$opts" in
        p) REFERENCE_IMAGE_PASSWORD="${OPTARG}";;
        t) THRESHOLD="${OPTARG}";;
        d) DEVICE="${OPTARG}";;
        u) REFERENCE_IMAGE_USER="${OPTARG}";;
        r) REFERENCE_IMAGE="${OPTARG}";;
        T) REFERENCE_IMAGE_TOKEN="${OPTARG}";;
        i) IMAGE="${OPTARG}";;
        h|*) usage ; exit 1 ;;
    esac
done

! check_root && error_msg "You need to be root to run this script."

# Test run.
create_out_dir "${OUTPUT}"

if [ -z "${REFERENCE_IMAGE}" ]; then
    error_msg "Reference image missing"
fi

ARGS="--lava --threshold ${THRESHOLD} --reference ${REFERENCE_IMAGE}"

if [ -n "${IMAGE}" ]; then
    ARGS="${ARGS} --image ${IMAGE}"
fi

if [ -n "${DEVICE}" ]; then
    ARGS="${ARGS} --device ${DEVICE}"
fi

if [ -n "${REFERENCE_IMAGE_USER}" ] && [ -n "${REFERENCE_IMAGE_PASSWORD}" ]; then
    ARGS="${ARGS} --reference-auth-user ${REFERENCE_IMAGE_USER} --reference-auth-password ${REFERENCE_IMAGE_PASSWORD}"
elif [ -n "${REFERENCE_IMAGE_TOKEN}" ]; then
    ARGS="${ARGS} --reference-auth-token ${REFERENCE_IMAGE_TOKEN}"
fi

# shellcheck disable=SC2086
python3 compare.py ${ARGS}
