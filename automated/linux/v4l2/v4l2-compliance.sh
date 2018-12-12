#!/bin/sh

. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
export RESULT_FILE="${OUTPUT}/result.txt"
TEST_SUITE="v4l2-compliance"

VIDEO_DEVICE="/dev/video0"
VIDEO_DRIVER=""

usage() {
    echo "Usage: $0 [-d <video device> -D <video driver>" 1>&2
    exit 1
}

while getopts "d:D:h" o; do
  case "$o" in
    d) VIDEO_DEVICE="${OPTARG}" ;;
    D) VIDEO_DRIVER="${OPTARG}" ;;
    h|*) usage ;;
  esac
done

echo VIDEO_DEVICE="${VIDEO_DEVICE}"
echo VIDEO_DRIVER="${VIDEO_DRIVER}"

# Test run.
create_out_dir "${OUTPUT}"

# Try to install v4l-utils when v4l2-compliance not found.
# install_deps() skips installation on unsupported distro
# like OE based builds by default.
which v4l2-compliance > /dev/null || install_deps "v4l-utils"
which v4l2-compliance > /dev/null
exit_on_fail "v4l2-existence-check"

if [ -n "${VIDEO_DRIVER}" ] && ! lsmod | grep "${VIDEO_DRIVER%.*}"; then
    check_root || error_msg "Please run this script as root to modprobe driver module!"
    ln -s "$(find "/lib/modules/$(uname -r)" -name "${VIDEO_DRIVER}*")" \
        "/lib/modules/$(uname -r)"
    depmod -a
    modprobe "${VIDEO_DRIVER%.*}" no_error_inj=1
    exit_on_fail "modprobe-${VIDEO_DRIVER%.*}"
fi

if [ ! -z "${VIDEO_DEVICE}" ] && [ -e "${VIDEO_DEVICE}" ]; then
  info_msg "Running v4l2-compliance device test..."
  LOG_FILE="${OUTPUT}/${TEST_SUITE}-output.txt"
  test_cmd="v4l2-compliance -v -d ${VIDEO_DEVICE} 2>&1"
  pipe0_status "${test_cmd}" "tee ${LOG_FILE}"
  check_return "v4l2-compliance"
else
  info_msg "Skipping v4l2-compliance device test..."
fi

# Parse test log.
grep -e FAIL -e OK "${LOG_FILE}" | \
  sed -e 's/^[ \t]*//' \
      -e 's/test //' \
      -e 's/ (Not Supported)//' \
      -e 's/ /_/g' \
      -e 's/:_/ /' \
      -e 's/ OK/ PASS/' \
      >> "${RESULT_FILE}"
