#!/bin/sh

# shellcheck disable=SC1091
. ../../lib/sh-test-lib

OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE

# The number of hardware class may vary dpending on the system under testing.
# This test check if lshw able to report the classes defined in ${CLASSES},
# which are very common ones by default and can be changed with -c.
CLASSES="system bus processor memory network"

usage() {
    echo "usage: $0 [-s <true|false>] [-c classes]" 1>&2
    exit 1
}

while getopts ':s:c:' opt; do
    case "${opt}" in
        s) SKIP_INSTALL="${OPTARG}" ;;
        c) CLASSES="${OPTARG}" ;;
        *) usage ;;
    esac
done

! check_root && error_msg "lshw must be run as super user or it will only report partial information."
create_out_dir "${OUTPUT}"

install_deps "lshw" "${SKIP_INSTALL}"

# If lshw fails to run, skip the following tests and exit.
skip_list=$(echo "${CLASSES}" | awk '{for (i=1; i<=NF; i++) printf("lshw-%s ",$i)}')
lshw > "${OUTPUT}/lshw.txt"
exit_on_fail "lshw-run" "${skip_list}"

# Obtain classes detected by lshw.
lshw -json > "${OUTPUT}/lshw.json"
detected_classes=$(grep '"class" : ' "${OUTPUT}/lshw.json" | awk -F'"' '{print $(NF-1)}' | uniq)

# Check if lshw able to detect and report the classes defined in ${CLASSES}.
for class in ${CLASSES}; do
    logfile="${OUTPUT}/lshw-${class}.txt"
    if ! echo "${detected_classes}" | grep -q "${class}"; then
        warn_msg "lshw failed to detect ${class} class!"
        report_fail "lshw-${class}"
    else
        # lshw may exit with zero and report nothing, so check the size of
        # logfile as well.
        if lshw -class "${class}" > "${logfile}" || ! test -s "${logfile}"; then
            report_pass "lshw-${class}"
        else
            report_fail "lshw-${class}"
        fi
        cat "${logfile}"
    fi
done
