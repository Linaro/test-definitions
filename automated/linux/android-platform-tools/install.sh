#!/bin/sh -ex
# shellcheck disable=SC1090
# shellcheck disable=SC1091

TEST_DIR=$(dirname "$(realpath "$0")")
OUTPUT="${TEST_DIR}/output"
export RESULT_FILE="${OUTPUT}/result.txt"
LINK="https://dl.google.com/android/repository/platform-tools-latest-linux.zip"

usage() {
    echo "Usage: $0 [-l <link>]" 1>&2
    exit 1
}

while getopts "l:h" opt; do
    case "$opt" in
        l) LINK="${OPTARG}" ;;
        *) usage ;;
    esac
done

. "${TEST_DIR}/../../lib/sh-test-lib"
create_out_dir "${OUTPUT}"

install_deps "wget unzip"
cd /opt/
rm -rf platform-tools*
wget -S --progress=dot:giga "${LINK}"
unzip -q "$(basename "${LINK}")"
cd platform-tools

install() {
    tool="$1"
    tool_path="$(realpath ./"${tool}")"

    if command -v "${tool}"; then
        remove_pkgs "${tool}"
        if command -v "${tool}"; then
            rm -f /usr/bin/"${tool}"
        fi
    fi
    ln -s "${tool_path}" "/usr/bin/"
    tool_link="$(realpath "$(which "${tool}")")"
    if [ "${tool_link}" = "${tool_path}" ]; then
        report_pass "install-${tool}"
    else
        report_fail "install-${tool}"
        exit 1
    fi
}

install fastboot
fastboot --version

install adb
adb version
