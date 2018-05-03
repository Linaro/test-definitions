#!/bin/sh -e

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE
MEMORY='1M'
ITERATIONS=1

usage() {
    echo "Usage: $0 [-s <true|false>] [-m memory] [-i iterations]" 1>&2
    exit 1
}

while getopts "s:m:i:h" o; do
  case "$o" in
    s) SKIP_INSTALL="${OPTARG}" ;;
    m) MEMORY="${OPTARG}" ;;
    i) ITERATIONS="${OPTARG}" ;;
    *) usage ;;
  esac
done

install() {
    dist_name
    # shellcheck disable=SC2154
    case "${dist}" in
      debian|ubuntu) install_deps "memtester" "${SKIP_INSTALL}";;
      unknown) warn_msg "Unsupported distro: package install skipped" ;;
    esac
}

parser() {
    test_log="$1"
    if [ "${ITERATIONS}" -gt 1 ]; then
        suffix="-iter$2"
    else
        suffix=""
    fi

    # The follow lines:
    # Remove redundant spaces.
    # Replace ok with pass.
    # Replace spaces in test case name with minus.
    # Save test results like 'Stuck-Address pass' to result file.
    grep ': ok' "${test_log}" \
        | sed 's/^ *//g; s/ *: ok/:pass/g; s/ /-/g' \
        | awk -v suffix="${suffix}" -F':' '{printf("%s%s %s\n",$1,suffix,$2)}' \
        | tee -a "$RESULT_FILE"
}

create_out_dir "${OUTPUT}"
install
for i in $(seq "${ITERATIONS}"); do
    output="${OUTPUT}/memtester-iter$i.txt"

    memtester "${MEMORY}" 1 \
        | sed 's/:.*ok/: ok/g' \
        | tee "${output}"

    parser "${output}" "$i"
done
