#!/bin/sh
set -x

CMD="/usr/bin/widevine_ce_cdm_unittest"
LOG_FILE="log.txt"
RESULT_FILE="result.txt"

usage() {
    echo "Usage: $0 [-l <log file> -r <test result file>]" 1>&2
    exit 1
}

while getopts "l:r:h" o; do
  case "$o" in
    l) LOG_FILE="${OPTARG}" ;;
    r) RESULT_FILE="${OPTARG}" ;;
    h|*) usage ;;
  esac
done

if [ ! -f "${CMD}" ]; then
    echo "Can not find ${CMD}"
    exit 1
fi

${CMD} > "${LOG_FILE}" 2>&1

# Fix can not loding shared libraries error
if grep -q "error while loading shared libraries" "${LOG_FILE}" ; then
    lib=$(awk -F: '{print $3}' "${LOG_FILE}" | sed 's/[[:space:]]*//g')
    dest_dir=$(dirname "${lib}")
    lib_name=$(basename "${lib}")
    mkdir -p "${dest_dir}"
    ln -s /usr/lib/"${lib_name}" "${dest_dir}"
    # Run the command again
    ${CMD} > "${LOG_FILE}" 2>&1
fi

grep "ms)$" "${LOG_FILE}" | \
  sed -e 's/\ (.*)$//' \
      -e 's/[[:space:]]*//g' \
      -e 's/=//' \
      -e 's/\[OK\]/pass:/' \
      -e 's/\[FAILED\]/fail:/' | \
  awk -F: '{print $2" "$1}' \
  > "${RESULT_FILE}"
