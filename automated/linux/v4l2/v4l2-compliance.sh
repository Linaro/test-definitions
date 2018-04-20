#!/bin/sh

. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
TEST_SUITE="v4l2-compliance"

usage() {
    echo "Usage: $0 [-d <video device>" 1>&2
    exit 1
}

while getopts "d:h:m:" o; do
  case "$o" in
    d) VIDEO_DEVICE="${OPTARG}" ;;
    m) MEDIA_DEVICE_NUM="${OPTARG}"
       MEDIA_DEVICE="/dev/media${OPTARG}" ;;
    h|*) usage ;;
  esac
done

echo VIDEO_DEVICE="${VIDEO_DEVICE}"
echo MEDIA_DEVICE="${MEDIA_DEVICE}"
echo MEDIA_DEVICE_NUM="${MEDIA_DEVICE_NUM}"

# Test run.
create_out_dir "${OUTPUT}"

command -v v4l2-compliance
exit_on_fail "v4l2-existence-check"

if [ ! -z "${VIDEO_DEVICE}" ] && [ -e "${VIDEO_DEVICE}" ]; then
  info_msg "Running v4l2-compliance device test..."
  LOG_FILE="${OUTPUT}/${TEST_SUITE}-output.txt"
  test_cmd="v4l2-compliance -v -d ${VIDEO_DEVICE} 2>&1"
  pipe0_status "${test_cmd}" "tee ${LOG_FILE}"
  check_return "v4l2-compliance"
else
  info_msg "Skipping v4l2-compliance device test..."
fi

if [ ! -z "${MEDIA_DEVICE}" ] && [ -e "${MEDIA_DEVICE}" ]; then
  info_msg "Running v4l2-compliance media test..."
  LOG_FILE="${OUTPUT}/${TEST_SUITE}-output.txt"
  test_cmd="v4l2-compliance -v -m${MEDIA_DEVICE_NUM} 2>&1"
  pipe0_status "${test_cmd}" "tee ${LOG_FILE}"
  check_return "v4l2-compliance"
else
  info_msg "Skipping v4l2-compliance media test..."
fi

# Parse test log.
grep -e FAIL -e OK "${LOG_FILE}" | \
  sed -e 's/^[ \t]*//' \
      -e 's/test //' \
      -e 's/ (Not Supported)//' \
      -e 's/ /_/g' \
      -e 's/:_/ /' \
      -e 's/ OK/ PASS/' \
      > "${RESULT_FILE}"
