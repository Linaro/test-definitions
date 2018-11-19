#!/bin/sh

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
LOG_FILE="smc_logfile"
export RESULT_FILE
SMC_VERSION=v0.40
SMC_PATH=/opt/spectre-meltdown-checker

usage() {
    echo "Usage: $0 [-s <true|false>] [-v <smc_version>]" 1>&2
    exit 1
}

while getopts "s:v:h" o; do
  case "$o" in
    s) SKIP_INSTALL="${OPTARG}" ;;
    v) SMC_VERSION="${OPTARG}" ;;
    h|*) usage ;;
  esac
done

smc_install() {
    mkdir -p "${SMC_PATH}"
    info_msg "Download spectre meltdown checker source code"
    # shellcheck disable=SC2140
    wget https://github.com/speed47/spectre-meltdown-checker/archive/"${SMC_VERSION}".tar.gz
    tar --strip-components=1 -xf "${SMC_VERSION}".tar.gz
}

# Parse SMC output
parse_smc_output() {
    grep "SUMMARY" "$1" \
        | cut -d' ' -f3-12 \
        | sed -e's/ /\n/g' \
        | sed 's/OK/pass/; s/KO/fail/'  >> "${RESULT_FILE}"
}

smc_run() {
    ./spectre-meltdown-checker.sh | tee "${OUTPUT}/${LOG_FILE}.log"
    parse_smc_output "${OUTPUT}/${LOG_FILE}.log"
}

# Create output directory
create_out_dir "${OUTPUT}"
if [ "${SKIP_INSTALL}" = "True" ] || [ "${SKIP_INSTALL}" = "true" ]; then
    info_msg "install skipped"
    # shellcheck disable=SC2164
    cd "${SMC_PATH}"
else
    info_msg "install spectre meltdown checker"
    smc_install
fi

# Test run
smc_run
