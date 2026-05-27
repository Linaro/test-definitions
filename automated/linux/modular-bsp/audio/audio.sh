#!/bin/bash
#
# audio.sh
#
# Advantech BSP QA – Audio device checks
# Ported from test_audio() in qa/test_board.sh
#
# Functional playback/recording tests (:F) are skip stubs in automated runs.
#
# Copyright (c) 2024 Advantech Co., Ltd. All rights reserved
#

# shellcheck source=../lib/adv-test-lib.sh
. "$(dirname "$0")/../lib/adv-test-lib.sh"

create_out_dir

: "${AUDIO_PLAYBACK_COUNT:=0}"
: "${AUDIO_CAPTURE_COUNT:=0}"

check_audio_device() {
    local mode="$1"   # pb or cap
    local n="$2"
    local cmd card controller dev_id codec label req_base

    case "${mode}" in
    pb)
        cmd="aplay"
        label="playback"
        eval "card=\${AUDIO_PB${n}_CARD}"
        eval "controller=\${AUDIO_PB${n}_CONTROLLER}"
        eval "codec=\${AUDIO_PB${n}_CODEC}"
        req_base="L-AUDIO-PLAYBACK-DEV-pb${n}"
        ;;
    cap)
        cmd="arecord"
        label="recording"
        eval "card=\${AUDIO_CAP${n}_CARD}"
        eval "controller=\${AUDIO_CAP${n}_CONTROLLER}"
        eval "codec=\${AUDIO_CAP${n}_CODEC}"
        req_base="L-AUDIO-RECORDING-DEV-cap${n}"
        ;;
    esac

    if ! chk_cmd "${cmd}"; then
        report_skip "${req_base}"
        return
    fi

    # Match card name and codec from aplay/arecord -l
    entry=$("${cmd}" -l 2>/dev/null | grep "${card}" | grep "${controller}:" | head -1)
    tcard=$(echo "${entry}" | awk -F'[' '{print $2}' | awk -F']' '{print $1}')
    tcodec=$(echo "${entry}" | awk -F'[' '{print $3}' | awk -F']' '{print $1}')

    if [ "${tcard}" = "${card}" ] && [ -n "${card}" ] && \
       [ "${tcodec}" = "${codec}" ]; then
        report_pass "${req_base}"
    else
        report_fail "${req_base}"
    fi
}

# ─── Playback devices ─────────────────────────────────────────────────────────

n=0
while [ "${n}" -lt "${AUDIO_PLAYBACK_COUNT}" ]; do
    check_audio_device pb "${n}"
    n=$((n + 1))
done

# ─── Capture devices ─────────────────────────────────────────────────────────

n=0
while [ "${n}" -lt "${AUDIO_CAPTURE_COUNT}" ]; do
    check_audio_device cap "${n}"
    n=$((n + 1))
done

# ─── Functional tests (skip stubs) ───────────────────────────────────────────
# These require a physical audio loopback cable and cannot be automated.

report_skip "L-AUDIO-PLAYBACK-F"
report_skip "L-AUDIO-RECORDING-F"
