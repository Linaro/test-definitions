#!/bin/sh

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
LOG_FILE="smc_logfile"
export RESULT_FILE
SMC_VERSION=v0.40
SKIP_INSTALL="False"
WGET_UPSTREAM="False"
SMC_PATH=/opt/spectre-meltdown-checker

usage() {
    echo "Usage: $0 [-s <true|false>] [-v <smc_version>] [-w <true|false>]" 1>&2
    exit 1
}

while getopts "s:v:w:h" o; do
  case "$o" in
    s) SKIP_INSTALL="${OPTARG}" ;;
    v) SMC_VERSION="${OPTARG}" ;;
    w) WGET_UPSTREAM="${OPTARG}" ;;
    h|*) usage ;;
  esac
done

smc_install() {
    mkdir -p "${SMC_PATH}"
    # shellcheck disable=SC2164
    cd "${SMC_PATH}"
    info_msg "Download spectre meltdown checker source code"
    # shellcheck disable=SC2140
    wget https://github.com/speed47/spectre-meltdown-checker/archive/"${SMC_VERSION}".tar.gz
    tar --strip-components=1 -xf "${SMC_VERSION}".tar.gz
}

# Parse SMC output
parse_smc_output() {
    awk '{print $1 " " $2}' "$1" \
        | sed 's/://' \
        | sed 's/OK/pass/; s/VULN/fail/; s/KO/fail/; s/UNK/skip/'  >> "${RESULT_FILE}"
}

smc_run() {
    ./spectre-meltdown-checker.sh  --no-color --batch | tee "${OUTPUT}/${LOG_FILE}.log"
    parse_smc_output "${OUTPUT}/${LOG_FILE}.log"
}

# Create output directory
create_out_dir "${OUTPUT}"

if [ "${SKIP_INSTALL}" = "True" ] || [ "${SKIP_INSTALL}" = "true" ]; then
    info_msg "install skipped"
    # shellcheck disable=SC2164
    cd "${SMC_PATH}"
elif [ "${WGET_UPSTREAM}" = "True" ] || [ "${WGET_UPSTREAM}" = "true" ]; then
    info_msg "install spectre meltdown checker"
    smc_install
else
    # Use the pre-copied spectre-meltdown-checker.sh from
    # cd test-definitions/automated/linux/spectre-meltdown-checker-test/bin
    # shellcheck disable=SC2164
    cd bin
fi

# Test run
smc_run
