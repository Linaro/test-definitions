#!/bin/sh

. ../../lib/sh-test-lib

OUTPUT="$(pwd)/output"
mkdir -p "${OUTPUT}"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE
TEST_SUITE="cryptsetup"

usage() {
    echo "Usage: $0 [-s] [-h <hash>] [-c <cipher>]" 1>&2
    exit 1
}

while getopts "h:c:s:" o; do
    case "$o" in
        h) HASH="${OPTARG}" ;;
        c) CIPHER="${OPTARG}" ;;
        s) SKIP_INSTALL="${OPTARG}" ;;
        *) usage ;;
    esac
done

echo HASH="${HASH}"
echo CIPHER="${CIPHER}"

create_out_dir "${OUTPUT}"

install_deps "cryptsetup" "${SKIP_INSTALL}"

# First test to check if cryptsetup is properly installed
cryptsetup --version
exit_on_fail "${TEST_SUITE}-version"

for h in ${HASH}; do
    LOG_FILE="${OUTPUT}/${TEST_SUITE}-hash-$h.txt"
    if pipe0_status "cryptsetup benchmark -h $h" "tee ${LOG_FILE}"; then
        # get metric
        iter=$(grep -v "^#" "${LOG_FILE}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | tr -s ' ' | cut -d' ' -f2)
        add_metric "${TEST_SUITE}-benchmark-hash-$h" "pass" "$iter" "iter/s"
    else
        report_fail "${TEST_SUITE}-benchmark-hash-$h"
    fi
done

for c in ${CIPHER}; do
    cipher=$(echo "$c" | cut -d'_' -f1)
    key=$(echo "$c" | cut -d'_' -f2)
    LOG_FILE="${OUTPUT}/${TEST_SUITE}-cipher-$c.txt"
    if pipe0_status "cryptsetup benchmark -c $cipher -s $key" "tee ${LOG_FILE}"; then
        # get metric
        result=$(grep -v "^#" "${LOG_FILE}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | tr -s ' ')
        enc=$(echo "$result" | cut -d' ' -f3)
        enc_unit=$(echo "$result" | cut -d' ' -f4)
        add_metric "${TEST_SUITE}-benchmark-cipher-$c-encryption" "pass" "$enc" "$enc_unit"
        dec=$(echo "$result" | cut -d' ' -f5)
        dec_unit=$(echo "$result" | cut -d' ' -f6)
        add_metric "${TEST_SUITE}-benchmark-cipher-$c-decryption" "pass" "$dec" "$dec_unit"
    else
        report_fail "${TEST_SUITE}-benchmark-cipher-$c-encryption"
        report_fail "${TEST_SUITE}-benchmark-cipher-$c-decryption"
    fi
done
