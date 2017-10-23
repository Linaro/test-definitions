#!/bin/sh -e

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE
PARTITION=""
IOENGINE="sync"
BLOCK_SIZE="4k"

usage() {
    echo "Usage: $0 [-p <partition>] [-b <block_size>] [-i <sync|psync|libaio>]
                    [-s <true|false>]" 1>&2
    exit 1
}

while getopts "p:b:i:s:" o; do
  case "$o" in
    # The current working directory will be used by default.
    # Use '-p' specify partition that used for fio test.
    p) PARTITION="${OPTARG}" ;;
    b) BLOCK_SIZE="${OPTARG}" ;;
    i) IOENGINE="${OPTARG}" ;;
    s) SKIP_INSTALL="${OPTARG}" ;;
    *) usage ;;
  esac
done

fio_build_install() {
    wget http://brick.kernel.dk/snaps/fio-2.1.10.tar.gz
    tar -xvf fio-2.1.10.tar.gz
    cd fio-2.1.10
    ./configure
    make all
    make install
}

install() {
    if which fio; then
        info_msg "fio has been already installed"
    else
        dist_name
        # shellcheck disable=SC2154
        case "${dist}" in
          debian|ubuntu)
            pkgs="fio"
            install_deps "${pkgs}" "${SKIP_INSTALL}"
            ;;
          fedora|centos)
            pkgs="libaio-devel gcc tar wget"
            install_deps "${pkgs}" "${SKIP_INSTALL}"
            fio_build_install
            ;;
          # When build do not have package manager
          # Assume development tools pre-installed
          *)
            fio_build_install
            ;;
        esac
    fi
}

fio_test() {
    # shellcheck disable=SC2039
    local rw="$1"
    file="${OUTPUT}/fio-${BLOCK_SIZE}-${rw}.txt"

    # Run fio test.
    echo
    info_msg "Running fio ${BLOCK_SIZE} ${rw} test ..."
    fio -name="${rw}" -rw="${rw}" -bs="${BLOCK_SIZE}" -size=1G -runtime=300 \
        -numjobs=1 -ioengine="${IOENGINE}" -direct=1 -group_reporting \
        -output="${file}"
    echo

    # Parse output.
    cat "${file}"
    measurement=$(grep -m 1 "iops=" "${file}" | cut -d= -f4 | cut -d, -f1)
    add_metric "fio-${rw}" "pass" "${measurement}" "iops"

    # Delete files created by fio to avoid out of space.
    rm -rf ./"${rw}"*
}

# Config test.
! check_root && error_msg "This script must be run as root"
create_out_dir "${OUTPUT}"

# Enter test directory.
if [ -n "${PARTITION}" ]; then
    if [ -b "${PARTITION}" ]; then
        if df | grep "${PARTITION}"; then
            mount_point=$(df | grep "${PARTITION}" | awk '{print $NF}')
        else
            mount_point="/media/fio"
            mkdir -p "${mount_point}"
            umount "${mount_point}" > /dev/null 2>&1 || true
            mount "${PARTITION}" "${mount_point}" && \
                info_msg "${PARTITION} mounted to ${mount_point}"
            df | grep "${PARTITION}"
        fi
        cd "${mount_point}"
    else
        error_msg "Block device ${PARTITION} NOT found"
    fi
fi

# Install and run fio test.
install
info_msg "About to run fio test..."
info_msg "Output directory: ${OUTPUT}"
info_msg "fio test directory: $(pwd)"
for rw in "read" randread write randwrite rw randrw; do
    fio_test "${rw}"
done
