#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2023 Foundries.io Ltd.

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE
TEST_LIST="basic-xbuf \
    clock-timer-periodic \
    clone-fork-exec \
    detach-self \
    duplicate-element \
    element-visibility \
    fault \
    fpu-preload \
    fpu-stress \
    heap-torture \
    mapfd \
    monitor-deadlock \
    monitor-deboost-stress \
    monitor-event \
    monitor-event-targeted \
    monitor-event-untrack \
    monitor-flags \
    monitor-flags-broadcast \
    monitor-pi \
    monitor-pi-deadlock \
    monitor-pi-deboost \
    monitor-pi-stress \
    monitor-pp-dynamic \
    monitor-pp-lazy \
    monitor-pp-lower \
    monitor-pp-nested \
    monitor-pp-pi \
    monitor-pp-raise \
    monitor-pp-tryenter \
    monitor-pp-weak \
    monitor-steal \
    monitor-trylock \
    monitor-wait-multiple \
    monitor-wait-requeue \
    observable-hm \
    observable-inband \
    observable-onchange \
    observable-oob \
    observable-race \
    observable-thread \
    observable-unicast \
    poll-close \
    poll-flags \
    poll-many \
    poll-multiple \
    poll-nested \
    poll-observable-inband \
    poll-observable-oob \
    poll-sem \
    poll-xbuf \
    proxy-echo \
    proxy-eventfd \
    proxy-pipe \
    proxy-poll \
    ring-spray \
    rwlock-read \
    rwlock-write \
    sched-quota-accuracy \
    sched-tp-accuracy \
    sched-tp-overrun \
    sem-close-unblock \
    sem-flush \
    sem-timedwait \
    sem-wait \
    simple-clone \
    stax-lock \
    stax-warn \
    thread-mode-bits"

usage() {
    echo "\
    Usage: $0 [-l TEST_LIST]

    -l <test_list>
        space separated list of tests to execute
        if ALL is used, 'evl test' is run without
        any arguments. This might lead to incomplete
        results as 'evl test' terminates on 1st failure
    "
}

while getopts "l:h" opts; do
    case "$opts" in
        l) TEST_LIST="${OPTARG}";;
        h|*) usage ; exit 1 ;;
    esac
done

# the script works only on builds with xenomai4 enabled

! check_root && error_msg "You need to be root to run this script."
create_out_dir "${OUTPUT}"

RESULTS=""

if [ "${TEST_LIST}" = "ALL" ]; then
    RESULTS=$(evl test)
else
    for TEST in ${TEST_LIST}
    do
        RESULTS+=$(evl test "${TEST}")
        RESULTS+=$'\n'
    done
fi

IFS=$'\n'
for LINE in ${RESULTS}
do
    echo "${LINE}"
    TEST_NAME=$(echo "${LINE}" | sed -E "s/([\*\ ]{0,})([a-z\-]+):.([A-Za-z\ ]+)|.*/\2/")
    TEST_RESULT=$(echo "${LINE}" | sed -E "s/([\*\ ]{0,})([a-z\-]+):.([A-Za-z\ ]+)|.*/\3/")
    case "${TEST_RESULT}" in
        "OK") report_pass "${TEST_NAME}";;
        "BROKEN") report_fail "${TEST_NAME}";;
        "no kernel support") report_skip "${TEST_NAME}";;
    esac
done
