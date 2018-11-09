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
adb_path="$(realpath ./adb)"

# Add the current directory to $PATH.
new_line="PATH=${PWD}:${PATH}"
# bash shell
grep "${new_line}" "/root/.bash_profile" || echo "${new_line}" >> "/root/.bash_profile"
# other shells
grep "${new_line}" "/root/.profile" || echo "${new_line}" >> "/root/.profile"

# Check if installed correctly.
. "/root/.profile"
if [ "$(which adb)" = "${adb_path}" ]; then
report_pass "install-android-platform-tools"
else
report_fail "install-android-platform-tools"
exit 1
fi
