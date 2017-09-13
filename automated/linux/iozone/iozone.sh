#!/bin/sh -ex
# shellcheck disable=SC1090
# shellcheck disable=SC2154

TEST_DIR=$(dirname "$(realpath "$0")")
OUTPUT="${TEST_DIR}/output"
LOGFILE="${OUTPUT}/iozone-stdout.txt"
RESULT_FILE="${OUTPUT}/result.txt"

SKIP_INSTALL="false"
VERSION="3_458"

usage() {
    echo "Usage: $0 [-s <skip_install>] [-v <version>]" 1>&2
    exit 1
}

while getopts "s:v:" opt; do
    case "$opt" in
        s) SKIP_INSTALL="${OPTARG}" ;;
        v) VERSION="${OPTARG}" ;;
        *) usage ;;
    esac
done

. "${TEST_DIR}/../../lib/sh-test-lib"
install_deps "wget gcc make" "$SKIP_INSTALL"
create_out_dir "${OUTPUT}"
cd "${OUTPUT}"

# Download, compile and run iozone3.
wget "http://www.iozone.org/src/stable/iozone${VERSION}.tar"
tar xf "iozone${VERSION}.tar"
cd "iozone${VERSION}/src/current"
detect_abi
case "$abi" in
    armeabi|arm64) make linux-arm ;;
    *) warn_msg "Unsupported architecture" ;;
esac
# -a: Auto mode
# -I: Use VxFS VX_DIRECT, O_DIRECT,or O_DIRECTIO for all file operations
./iozone -a -I | tee "$LOGFILE"

# Parse iozone stdout.
field_number=1
for test in "write" "rewrite" "read" "reread" "random-read" "random-write" "bkwd-read" \
    "record-rewrite" "stride-read" "fwrite" "frewrite" "fread" "freread"; do
    awk "/kB  reclen/{flag=1; next} /iozone test complete./{flag=0} flag" "$LOGFILE"  \
        | sed '/^$/d' \
        | awk -v tc="$test" -v field_number="$field_number" \
            '{printf("%s-%skB-%sreclen pass %s kBytes/sec\n",tc,$1,$2,$field_number)}' \
        | tee -a "$RESULT_FILE"
    field_number=$(( field_number + 1 ))
done
