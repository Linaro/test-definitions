#!/bin/sh -e

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE
LOGFILE="${OUTPUT}/kernel-compilation.txt"
VERSION='4.4.34'

usage() {
    echo "Usage: $0 [-v version] [-s true|false]" 1>&2
    exit 1
}

while getopts "v:s:h" o; do
    case "$o" in
        v) VERSION="${OPTARG}" ;;
        s) SKIP_INSTALL="${OPTARG}" ;;
        h|*) usage ;;
    esac
done

dist_name
# shellcheck disable=SC2154
case "${dist}" in
    Debian|Ubuntu) pkgs="time bc xz-utils build-essential" ;;
    CentOS|Fedora) pkgs="time bc xz gcc make" ;;
esac
! check_root && error_msg "You need to be root to install packages!"
# install_deps supports the above distributions.
# It will skip package installation on other distributions by default.
install_deps "${pkgs}" "${SKIP_INSTALL}"

[ -d "${OUTPUT}" ] && mv "${OUTPUT}" "${OUTPUT}_$(date +%Y%m%d%H%M%S)"
mkdir -p "${OUTPUT}"
cd "${OUTPUT}"

# Download and extract Kernel tarball.
major_version=$(echo "${VERSION}" | awk -F'.' '{print $1}')
wget "https://cdn.kernel.org/pub/linux/kernel/v${major_version}.x/linux-${VERSION}.tar.xz"
tar xf "linux-${VERSION}.tar.xz"
cd "linux-${VERSION}"

# Compile Kernel with defconfig.
make defconfig
processor_number=$(grep -c "processor" /proc/cpuinfo)
{ time -p make -j"${processor_number}" Image; } 2>&1 | tee "${LOGFILE}"

measurement="$(grep "^real" "${LOGFILE}" | awk '{print $2}')"
if egrep "arch/.*/boot/Image" "${LOGFILE}"; then
    report_pass "kernel-compilation"
    add_metric "kernel-compilation-time" "pass" "${measurement}" "seconds"
else
    report_fail "kernel-compilation"
    add_metric "kernel-compilation-time" "fail" "${measurement}" "seconds"
fi

# Cleanup.
cd ../
rm -rf "linux-${VERSION}"*
