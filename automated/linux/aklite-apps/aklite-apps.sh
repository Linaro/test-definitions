#!/bin/bash -e
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2024 Foundries.io Ltd.

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE
APPS=""
DEFAULT_APPS=""
LOOP_APPS=""
APPS_ARG=""

usage() {
    echo "\
    Usage: $0 -a <app1,app2> -d <app1,app2>

    -a <app1,app2>
        Comma separated list of apps to start
    -d <app1,app2>
        Comma separated list of default apps to start
        This option is ignored when -a is used.
        When using -d without -a script calls 'aklite-apps run'
        without any parameters.
    "
}

while getopts "a:d:h" opts; do
    case "$opts" in
        a) APPS="${OPTARG}";;
        d) DEFAULT_APPS="${OPTARG}";;
        h|*) usage ; exit 1 ;;
    esac
done


! check_root && error_msg "You need to be root to run this script."
create_out_dir "${OUTPUT}"

if [ -n "${APPS}" ]; then
    APPS_ARG=" --apps ${APPS}"
    LOOP_APPS="${APPS}"
elif [ -n "${DEFAULT_APPS}" ]; then
    LOOP_APPS="${DEFAULT_APPS}"
else
    error_msg "List of apps to check missing"
fi

# shellcheck disable=SC2086
aklite-apps run ${APPS_ARG}

# LOOP_APPS can't be empty at this point
IFS=","
for app in ${LOOP_APPS}
do
    docker ps | grep "${app}"
    check_return "${app}-running"
done
