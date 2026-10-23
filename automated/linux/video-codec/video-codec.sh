#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2026 Qualcomm Technologies, Inc. and/or its subsidiaries.
#
# V4L2 stateful video codec check through FFmpeg's v4l2m2m wrappers.
#
# Decode: every reference stream <codec>-*.<ext> in the streams directory is
# decoded by the hardware to NV12 and the MD5 of every frame must equal the
# software decode recorded next to it (<stream>.md5, one hash per line).
# Encode: testsrc2 frames are encoded by the hardware; the stream must decode
# in software to the same frame count with a PSNR of at least MIN_PSNR dB.
# Then, with the platform device and driver given: a decode after the codec
# runtime suspended, a decode after an unbind and bind of the driver, and the
# negative case: with the firmware file hidden the driver must either fail to
# probe and register no video node (firmware loaded at probe) or fail the
# decode (firmware loaded at the first open); with it restored the next bind
# must decode again. Every FFmpeg run is bounded by FFMPEG_TIMEOUT seconds.
# Without a codec video node the test is skipped.

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE

DEVICE=""
DRIVER=""
DECODERS="h264 hevc vp9"
ENCODERS="h264"
STREAMS="/usr/share/video-codec"
FIRMWARE=""
MIN_PSNR=30
ENCODE_SIZE="1280x736"
FFMPEG="ffmpeg"
# Upper bound for one FFmpeg run, in seconds.
FFMPEG_TIMEOUT=60

usage() {
    echo "Usage: $0 [-d <platform device>] [-r <platform driver>]" \
        "[-D <decoders>] [-E <encoders>] [-s <streams dir>]" \
        "[-f <firmware file>] [-p <min psnr>] [-S <encode WxH>]" \
        "[-b <ffmpeg>]" 1>&2
    exit 1
}

while getopts "d:r:D:E:s:f:p:S:b:h" o; do
    case "$o" in
        d) DEVICE="${OPTARG}" ;;
        r) DRIVER="${OPTARG}" ;;
        D) DECODERS="${OPTARG}" ;;
        E) ENCODERS="${OPTARG}" ;;
        s) STREAMS="${OPTARG}" ;;
        f) FIRMWARE="${OPTARG}" ;;
        p) MIN_PSNR="${OPTARG}" ;;
        S) ENCODE_SIZE="${OPTARG}" ;;
        b) FFMPEG="${OPTARG}" ;;
        h|*) usage ;;
    esac
done

create_out_dir "${OUTPUT}"
# A run killed while the firmware was hidden leaves it hidden.
if [ -n "${FIRMWARE}" ] && [ -f "${FIRMWARE}.hidden" ] && [ ! -e "${FIRMWARE}" ]; then
    warn_msg "restoring ${FIRMWARE} hidden by an earlier run"
    mv "${FIRMWARE}.hidden" "${FIRMWARE}"
fi

# bounded <log> <command...>: run the command with its output in <log>, kill
# it after FFMPEG_TIMEOUT seconds; returns its exit status, 124 on timeout.
bounded() {
    log=$1
    shift
    "$@" > "${log}" 2>&1 &
    pid=$!
    t=0
    while kill -0 "${pid}" 2> /dev/null; do
        if [ "${t}" -ge "${FFMPEG_TIMEOUT}" ]; then
            kill "${pid}" 2> /dev/null
            sleep 1
            kill -9 "${pid}" 2> /dev/null
            wait "${pid}" 2> /dev/null
            echo "timed out after ${FFMPEG_TIMEOUT} s" >> "${log}"
            return 124
        fi
        sleep 1
        t=$((t + 1))
    done
    wait "${pid}"
}

# Video nodes of DEVICE; every video node when DEVICE is empty, cameras
# included, so boards with cameras need DEVICE for video-codec-nodes.
video_nodes() {
    for v in /sys/class/video4linux/video*; do
        [ -e "${v}" ] || continue
        if [ -n "${DEVICE}" ]; then
            readlink -f "${v}/device" | grep -q "/${DEVICE}" || continue
        fi
        echo "/dev/$(basename "${v}") $(cat "${v}/name")"
    done
}

wait_nodes() {
    i=0
    while [ "${i}" -lt 20 ]; do
        [ -n "$(video_nodes)" ] && return 0
        sleep 1
        i=$((i + 1))
    done
    return 1
}

stream_for() {
    for s in "${STREAMS}/${1}"-*; do
        case "${s}" in
            *.md5) continue ;;
        esac
        [ -f "${s}" ] && [ -f "${s}.md5" ] && echo "${s}" && return 0
    done
    return 1
}

frame_hashes() {
    grep -v '^#' "$1" | awk -F, '{gsub(/ /, "", $6); print $6}'
}

# decode <codec> <test case>
decode() {
    s="$(stream_for "$1")" || { warn_msg "no $1 stream in ${STREAMS}"; report_skip "$2"; return; }
    out="${OUTPUT}/$2.framemd5"
    rm -f "${out}" "${out}.hashes"
    # The v4l2m2m wrapper does not keep the timestamps: pass every frame.
    if ! bounded "${OUTPUT}/$2.log" "${FFMPEG}" -hide_banner -loglevel verbose \
        -c:v "$1_v4l2m2m" -i "${s}" -fps_mode passthrough -pix_fmt nv12 \
        -f framemd5 "${out}"; then
        tail -n 15 "${OUTPUT}/$2.log"
        report_fail "$2"
        return
    fi
    frame_hashes "${out}" > "${out}.hashes"
    got=$(wc -l < "${out}.hashes")
    want=$(wc -l < "${s}.md5")
    if [ "${got}" -eq "${want}" ] && cmp -s "${out}.hashes" "${s}.md5"; then
        info_msg "$2: ${got} frames match the software decode of $(basename "${s}")"
        report_pass "$2"
    else
        bad=$(awk 'NR == FNR { h[FNR] = $0; next } h[FNR] != $0 { n++ } END { print n + 0 }' \
            "${out}.hashes" "${s}.md5")
        info_msg "$2: ${got} frames (want ${want}), ${bad} differ from the software decode"
        report_fail "$2"
    fi
}

# encode <codec> <test case>
encode() {
    case "$1" in
        h264) fmt=h264 ;;
        hevc) fmt=hevc ;;
        *) warn_msg "no container for $1"; report_skip "$2"; return ;;
    esac
    # A size without padding: FFmpeg's v4l2m2m encoder copies the driver's
    # padded plane height out of the source frame.
    src="testsrc2=size=${ENCODE_SIZE}:rate=30"
    n=60
    out="${OUTPUT}/$2.${fmt}"
    rm -f "${out}"
    if ! bounded "${OUTPUT}/$2.log" "${FFMPEG}" -hide_banner -loglevel verbose \
        -f lavfi -i "${src}" -frames:v "${n}" -pix_fmt nv12 \
        -c:v "$1_v4l2m2m" -b:v 4M -f "${fmt}" "${out}"; then
        tail -n 15 "${OUTPUT}/$2.log"
        report_fail "$2"
        return
    fi
    got=$("${FFMPEG}" -hide_banner -loglevel error -i "${out}" -f framemd5 - | grep -vc '^#')
    psnr=$("${FFMPEG}" -hide_banner -framerate 30 -i "${out}" -f lavfi -i "${src}" -frames:v "${n}" \
        -lavfi "[0:v]format=yuv420p[a];[1:v]format=yuv420p[b];[a][b]psnr" \
        -f null - 2>&1 | sed -n 's/.*PSNR.* average:\([0-9.]*\).*/\1/p' | tail -n 1)
    info_msg "$2: $(wc -c < "${out}") bytes, ${got} frames, PSNR ${psnr:-none} dB"
    if [ "${got}" -eq "${n}" ] && [ -n "${psnr}" ] &&
        awk -v p="${psnr}" -v m="${MIN_PSNR}" 'BEGIN { exit !(p >= m) }'; then
        report_pass "$2"
    else
        report_fail "$2"
    fi
}

bind() {
    echo "${DEVICE}" > "/sys/bus/platform/drivers/${DRIVER}/bind" 2>/dev/null
}

unbind() {
    echo "${DEVICE}" > "/sys/bus/platform/drivers/${DRIVER}/unbind" 2>/dev/null
}

if ! command -v "${FFMPEG}" > /dev/null; then
    warn_msg "${FFMPEG} is not installed"
    report_skip "video-codec-nodes"
    exit 0
fi
if ! wait_nodes; then
    info_msg "no video codec node${DEVICE:+ for ${DEVICE}}"
    report_skip "video-codec-nodes"
    exit 0
fi
video_nodes
report_pass "video-codec-nodes"

for c in ${DECODERS}; do
    decode "${c}" "decode-${c}"
done
for c in ${ENCODERS}; do
    encode "${c}" "encode-${c}"
done

if [ -z "${DEVICE}" ] || [ -z "${DRIVER}" ]; then
    exit 0
fi
first="${DECODERS%% *}"
pm="/sys/bus/platform/devices/${DEVICE}/power/runtime_status"

i=0
while [ "${i}" -lt 15 ] && [ "$(cat "${pm}")" != suspended ]; do
    sleep 1
    i=$((i + 1))
done
info_msg "runtime status after ${i} s idle: $(cat "${pm}")"
if [ "$(cat "${pm}")" = suspended ]; then
    report_pass "runtime-suspend"
else
    report_fail "runtime-suspend"
fi
decode "${first}" "decode-${first}-after-suspend"

unbind
bind
if wait_nodes; then
    report_pass "rebind"
else
    report_fail "rebind"
fi
decode "${first}" "decode-${first}-after-rebind"

if [ -z "${FIRMWARE}" ]; then
    exit 0
fi
if [ ! -f "${FIRMWARE}" ]; then
    warn_msg "${FIRMWARE} not found"
    report_skip "firmware-missing"
    exit 0
fi
unbind
mv "${FIRMWARE}" "${FIRMWARE}.hidden"
trap 'mv "${FIRMWARE}.hidden" "${FIRMWARE}"' EXIT
trap 'exit 1' INT TERM
lines=$(dmesg | wc -l)
bind
sleep 5
nodes="$(video_nodes)"
# A driver that loads its firmware at probe (venus) must not probe; one that
# loads it when a node is first opened (iris) probes, but must not decode.
nodec=""
if [ -n "${nodes}" ] && s="$(stream_for "${first}")" &&
    ! bounded "${OUTPUT}/firmware-missing.log" "${FFMPEG}" -hide_banner \
        -c:v "${first}_v4l2m2m" -i "${s}" -frames:v 1 -f null -; then
    nodec=yes
fi
dmesg | tail -n +"$((lines + 1))" | grep -i "${DEVICE}" | tail -n 5
if [ -z "${nodes}" ] && [ ! -e "/sys/bus/platform/drivers/${DRIVER}/${DEVICE}" ]; then
    report_pass "firmware-missing"
elif [ -n "${nodec}" ]; then
    info_msg "the driver probed without its firmware, but no ${first} decode ran"
    report_pass "firmware-missing"
else
    info_msg "the driver probed and decoded without its firmware: ${nodes}"
    report_fail "firmware-missing"
fi
mv "${FIRMWARE}.hidden" "${FIRMWARE}"
trap - EXIT INT TERM
unbind
bind
if wait_nodes; then
    report_pass "firmware-restored"
else
    report_fail "firmware-restored"
fi
decode "${first}" "decode-${first}-after-recovery"
exit 0
