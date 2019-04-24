#!/bin/sh

BIG_CPU_PART="0xd08"
LIST_BIG_CPUS=""

find_cpu () {
    PART=$1

    while read -r LINE; do
        IFS=':'
        # shellcheck disable=SC2039
        # shellcheck disable=SC2206
        TOKENS=(${LINE})
        if [ "${LINE#'processor'}" != "${LINE}" ]; then
	    CPU="${TOKENS[1]##' '}"
        elif [ "${LINE#'CPU part'}" != "${LINE}" ]; then
            GET_PART="${TOKENS[1]##' '}"
            if [ "${PART}" = "${GET_PART}" ]; then
                printf "%s ${CPU}"
	    fi
	fi
    done < /proc/cpuinfo
}

offline_big_cpus () {
    for CPU in ${LIST_BIG_CPUS}; do
        echo 0 > /sys/devices/system/cpu/cpu${CPU}/online
    done
}

online_big_cpus () {
    for CPU in ${LIST_BIG_CPUS}; do
        echo 1 > /sys/devices/system/cpu/cpu${CPU}/online
    done
}

LIST_BIG_CPUS="$( find_cpu ${BIG_CPU_PART} )"
