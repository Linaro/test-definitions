#!/bin/sh -e

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE
PARTITION=""
IOENGINE="sync"
BS_LIST="4k 512k"

usage() {
    echo "Usage: $0 [-p <partition>] [-b <bs_list>] [-i <sync|psync|libaio>]
                    [-s <true>]" 1>&2
    exit 1
}

while getopts "p:b:i:s:" o; do
  case "$o" in
    # The current working directory will be used by default.
    # Use '-p' specify partition that used for dd test.
    p) PARTITION="${OPTARG}" ;;
    b) BS_LIST="${OPTARG}" ;;
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
    dist_name
    # shellcheck disable=SC2154
    case "${dist}" in
      Debian|Ubuntu)
        pkgs="fio"
        install_deps "${pkgs}" "${SKIP_INSTALL}"
        ;;
      Fedora|CentOS)
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
}

parse_output() {
    test="$1"
    file="$2"
    IOPS=$(grep "iops=" "${file}" | cut -d= -f4 | cut -d, -f1)
    add_metric "${test}" "pass" "${IOPS}" "iops"
}

fio_read() {
    block_size="$1"
    file="${OUTPUT}/fio-${block_size}-read.txt"

    info_msg "Running fio ${block_size} read test..."
    fio -name=read -rw=read -bs="${block_size}" -size=1G -runtime=300 \
        -numjobs=1 -ioengine="${IOENGINE}" -direct=1 -group_reporting \
        -output="${file}"
    echo

    parse_output "fio-${block_size}-read" "${file}"
    rm -rf ./read*
}

fio_randread() {
    block_size="$1"
    file="${OUTPUT}/fio-${block_size}-randread.txt"

    info_msg "Running fio ${block_size} randread test..."
    fio -name=randread -rw=randread -bs="${block_size}" -size=1G -runtime=300 \
        -ioengine="${IOENGINE}" -direct=1 -group_reporting -output="${file}"
    echo

    parse_output "fio-${block_size}-randread" "${file}"
    rm -rf ./randread*
}

fio_write() {
    block_size="$1"
    file="${OUTPUT}/fio-${block_size}-write.txt"

    info_msg "Running fio ${block_size} write test..."
    fio -name=write -rw=write -bs="${block_size}" -size=1G -runtime=300 \
        -ioengine="${IOENGINE}" -direct=1 -group_reporting -output="${file}"
    echo

    parse_output "fio-${block_size}-write" "${file}"
    rm -rf ./write*
}

fio_randwrite() {
    block_size="$1"
    file="${OUTPUT}/fio-${block_size}-randwrite.txt"

    info_msg "Running fio ${block_size} randwrite test..."
    fio -name=randwrite -rw=randwrite -bs="${block_size}" -size=1G \
        -runtime=300 -ioengine="${IOENGINE}" -direct=1 -group_reporting \
        -output="${file}"
    echo

    parse_output "fio-${block_size}-randwrite" "${file}"
    rm -rf ./randwrite*
}

# Test run.
! check_root && error_msg "This script must be run as root"
[ -d "${OUTPUT}" ] && mv "${OUTPUT}" "${OUTPUT}_$(date +%Y%m%d%H%M%S)"
mkdir -p "${OUTPUT}"

# Enter test directory.
if [ -n "${PARTITION}" ]; then
    if [ -b "${PARTITION}" ]; then
        umount /mnt > /dev/null 2>&1 || true
        mount "${PARTITION}" /mnt && info_msg "${PARTITION} mounted to /mnt"
        df | grep "${PARTITION}"
        cd /mnt
    else
        error_msg "Block device ${PARTITION} NOT found"
    fi
fi

install
info_msg "About to run fio test..."
info_msg "Output directory: ${OUTPUT}"
info_msg "fio test directory: $(pwd)"
for bs in ${BS_LIST}; do
    fio_read "${bs}"
    fio_randread "${bs}"
    fio_write "${bs}"
    fio_randwrite "${bs}"
done
