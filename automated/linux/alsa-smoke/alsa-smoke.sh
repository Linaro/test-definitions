#!/bin/sh

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE
REFERENCE_PATH="/dev/snd"
SKIP_INSTALL="False"

usage() {
    echo "Usage: $0 [-s <true|false>] [-p </path/to/snd/devices>]" 1>&2
    exit 1
}

while getopts "s:p:h" o; do
  case "$o" in
    s) SKIP_INSTALL="${OPTARG}" ;;
    p) REFERENCE_PATH="${OPTARG}" ;;
    h|*) usage ;;
  esac
done

install() {
    dist_name
    # shellcheck disable=SC2154
    case "${dist}" in
      debian|ubuntu) install_deps "alsa-utils" "${SKIP_INSTALL}";;
      fedora|centos) install_deps "alsa-utils" "${SKIP_INSTALL}";;
      unknown) warn_msg "Unsupported distro: package install skipped" ;;
    esac
}

run() {
    # shellcheck disable=SC3043
    local test_command="$1"
    # shellcheck disable=SC3043
    local test_name="$2"
    # shellcheck disable=SC2086
    if command -v ${test_command}; then
        # shellcheck disable=SC2086
        if ${test_command} -l | grep "card [0-9]"; then
            report_pass "${test_name}_devices"
        else
            report_fail "${test_name}_devices"
        fi
    else
        # shellcheck disable=SC2086
        # shellcheck disable=SC2012
        DEVICES=$(find ${REFERENCE_PATH} -type c -name "controlC*" | wc -l)
        if [ "${DEVICES}" -gt 0 ]; then
            report_pass "${test_name}_devices"
        else
            report_fail "${test_name}_devices"
        fi
    fi
}

# Test run.
create_out_dir "${OUTPUT}"

install

run aplay playback
run arecord record
