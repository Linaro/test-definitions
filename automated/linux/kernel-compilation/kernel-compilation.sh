#!/bin/sh -e

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE
LOGFILE="${OUTPUT}/kernel-compilation.txt"
VERSION='4.4'
NPROC=$(nproc)

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
    debian|ubuntu) pkgs="wget time bc xz-utils build-essential" ;;
    centos|fedora) pkgs="wget time bc xz gcc make" ;;
esac
! check_root && error_msg "You need to be root to install packages!"
# install_deps supports the above distributions.
# It will skip package installation on other distributions by default.
install_deps "${pkgs}" "${SKIP_INSTALL}"

create_out_dir "${OUTPUT}"
cd "${OUTPUT}"

# Download and extract Kernel tarball.
wget "https://github.com/torvalds/linux/archive/v${VERSION}.tar.gz"
tar xf "v${VERSION}.tar.gz"
cd "linux-${VERSION}"

# Compile Kernel with defconfig.
# It is native not cross compiling.
# It will not work on x86.
detect_abi
# shellcheck disable=SC2154
case "${abi}" in
    arm64|armeabi)
        make defconfig
        { time -p make -j"${NPROC}" Image; } 2>&1 | tee "${LOGFILE}"
        ;;
    *)
        error_msg "Unsupported architecture!"
        ;;
esac

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
