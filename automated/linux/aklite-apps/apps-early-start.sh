#!/bin/bash -e
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2024 Foundries.io Ltd.

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE
DEFAULT_APPS=""

usage() {
    echo "\
    Usage: $0 -d <app1,app2>

    -d <app1,app2>
        Comma separated list of default apps to start
    "
}

while getopts "d:h" opts; do
    case "$opts" in
        d) DEFAULT_APPS="${OPTARG}";;
        h|*) usage ; exit 1 ;;
    esac
done


! check_root && error_msg "You need to be root to run this script."
create_out_dir "${OUTPUT}"

systemctl enable --now compose-apps-early-start
check_return "compose-apps-early-start"

if [ -n "${DEFAULT_APPS}" ]; then
    IFS=","
    for app in ${DEFAULT_APPS}
    do
        docker ps | grep "${app}"
        check_return "${app}-running"
    done
else
    report-skip "early-start-apps"
fi
