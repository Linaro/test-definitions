#!/system/bin/sh
# shellcheck disable=SC2039
# shellcheck disable=SC2086
# shellcheck disable=SC2181
# shellcheck disable=SC2155
# shellcheck disable=SC2166
# shellcheck disable=SC2320
# shellcheck disable=SC3006
# shellcheck disable=SC3010
# shellcheck disable=SC3018
# shellcheck disable=SC3037
# shellcheck disable=SC3057
# shellcheck disable=SC3060
#############################################################################
# Copyright (c) 2014 Linaro
# Copyright (c) 2025 Qualcomm Inc
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
#
# Contributors:
#     Linaro <linaro-dev@lists.linaro.org>
#     Milosz Wasilewski <milosz.wasilewski@oss.qualcomm.com>
#############################################################################

# Individual and batch test definitions
ALL_AUDIO_CODECS="audio_codec_aac audio_codec_flac audio_codec_mp3 \
	audio_codec_tremolo"
ALL_SPEECH_CODECS="speech_codec_amrnb_dec speech_codec_amrnb_enc \
	speech_codec_amrwb_dec speech_codec_amrwb_enc"
ALL_VIDEO_CODECS="video_codec_h264_dec video_codec_h264_enc \
	video_codec_h263_dec video_codec_h263_enc"
ALL_CODECS="${ALL_AUDIO_CODECS} ${ALL_SPEECH_CODECS} ${ALL_VIDEO_CODECS}"
ALL_TESTS="${ALL_CODECS}"

# Script arguments for selecting tests to run
ALL_AUDIO_CODECS_OPT="all_audio_codecs"
ALL_SPEECH_CODECS_OPT="all_speech_codecs"
ALL_VIDEO_CODECS_OPT="all_video_codecs"
ALL_CODECS_OPT="all_codecs"
ALL_TESTS_OPT="all_tests"

func_md5(){
    if [ -n "$(which md5)" ]; then
        md5 "$@"
    else
        md5sum "$@"
    fi
}

usage() {
	echo
	echo "Usage: $0 [-h] [-t TESTS] [-v]"
	echo "Run all or specified Android userspace tests"
	echo
	printf "  %-10s\t%s\n" "-h" "Print this help message"
	printf "  %-10s\t%s\n" "-t TESTS" "Run only specified TESTS from the following:"
	printf "  %-10s\t%s\n" "" "Individual tests:"
	for CODEC in ${ALL_CODECS}; do
		printf "  %-10s\t\t%s\n" "" "${CODEC}"
	done
	printf "  %-10s\t%s\n" "" "Batch tests:"
	printf "  %-10s\t\t%s\n" "" "${ALL_AUDIO_CODECS_OPT}"
	printf "  %-10s\t\t%s\n" "" "${ALL_SPEECH_CODECS_OPT}"
	printf "  %-10s\t\t%s\n" "" "${ALL_VIDEO_CODECS_OPT}"
	printf "  %-10s\t\t%s\n" "" "${ALL_CODECS_OPT}"
	printf "  %-10s\t\t%s\n" "" "${ALL_TESTS_OPT}"
	printf "  %-10s\t%s\n" "-v" "Turn on verbose output"
	echo
	echo "Example:"
	printf "\t%s -t \"audio_codec_aac speech_codec_amrnb_dec\"\n" "$0"
}

run_audio_codec_aac()
{
	local TEST_FILE="/data/linaro-android-userspace-test/audio-codec/Retribution.wav"
	local OUT_FILE="/data/local/tmp/audio-codec-test.out"
	local EXPECTED_MD5SUM="f35771514701eaf5055b1705a4c660b7"

	echo
	echo "Running AAC encoder test"

	if [ ! -f ${TEST_FILE} ]; then
		echo "ERROR: AAC encoder test file ${TEST_FILE} does not exist"
		echo "AAC encoder test: FAILED"
		echo "[audio_codec_aac]: test failed"
		return 1
	fi
	if [ "${VERBOSE}" -eq "1" ]; then
		libaacenc_test ${TEST_FILE} ${OUT_FILE}
	else
		libaacenc_test ${TEST_FILE} ${OUT_FILE} > /dev/null 2>&1
	fi
	if [ "$?" -ne "0" ]; then
		echo "ERROR: AAC encoder test returned error"
		echo "AAC encoder test: FAILED"
		echo "[audio_codec_aac]: test failed"
		return 1
	fi

	echo "Checking MD5SUM of output file"
	local MD5SUM="$(func_md5 ${OUT_FILE})"
	MD5SUM=${MD5SUM%% *}
	rm ${OUT_FILE}
	if [[ "${MD5SUM}" == "${EXPECTED_MD5SUM}" ]]; then
		echo "AAC encoder test: PASSED"
		echo "[audio_codec_aac]: test passed"
	else
		echo "ERROR: incorrect MD5SUM '${MD5SUM}' (expected '${EXPECTED_MD5SUM}')"
		echo "AAC encoder test: FAILED"
		echo "[audio_codec_aac]: test failed"
		return 1
	fi
}

run_audio_codec_flac()
{
	echo
	echo "Running FLAC encoder/decoder test"

	if [ "${VERBOSE}" -eq "1" ]; then
		libFLAC_test
	else
		libFLAC_test > /dev/null 2>&1
	fi
	if [ "$?" -eq "0" ]; then
		echo "FLAC encoder/decoder test: PASSED"
		echo "[audio_codec_flac]: test passed"
	else
		echo "ERROR: FLAC encoder/decoder test returned error"
		echo "FLAC encoder/decoder test: FAILED"
		echo "[audio_codec_flac]: test failed"
		return 1
	fi
}

run_audio_codec_mp3()
{
	local TEST_FILE="/data/linaro-android-userspace-test/audio-codec/Retribution.mp3"
	local OUT_FILE="/data/local/tmp/audio-codec-test.out"
	local EXPECTED_MD5SUM="bf1456a93dfc53e474c30c9fca75c647"

	echo
	echo "Running MP3 decoder test"

	if [ ! -f ${TEST_FILE} ]; then
		echo "ERROR: MP3 test file ${TEST_FILE} does not exist"
		echo "MP3 decoder test: FAILED"
		echo "[audio_codec_mp3]: test failed"
		return 1
	fi
	if [ "${VERBOSE}" -eq "1" ]; then
		libstagefright_mp3dec_test ${TEST_FILE} ${OUT_FILE}
	else
		libstagefright_mp3dec_test ${TEST_FILE} ${OUT_FILE} > /dev/null 2>&1
	fi
	if [ "$?" -ne "0" ]; then
		echo "ERROR: MP3 decoder test returned error"
		echo "MP3 decoder test: FAILED"
		echo "[audio_codec_mp3]: test failed"
		return 1
	fi

	echo "Checking MD5SUM of output file"
	local MD5SUM="$(func_md5 ${OUT_FILE})"
	MD5SUM=${MD5SUM%% *}
	rm ${OUT_FILE}
	if [[ "${MD5SUM}" == "${EXPECTED_MD5SUM}" ]]; then
		echo "MP3 decoder test: PASSED"
		echo "[audio_codec_mp3]: test passed"
	else
		echo "ERROR: incorrect MD5SUM '${MD5SUM}' (expected '${EXPECTED_MD5SUM}')"
		echo "MP3 decoder test: FAILED"
		echo "[audio_codec_mp3]: test failed"
		return 1
	fi
}

run_audio_codec_tremolo()
{
	local TEST_FILE="/data/linaro-android-userspace-test/audio-codec/Retribution.ogg"
	local OUT_FILE="/data/local/tmp/audio-codec-test.out"
	local EXPECTED_MD5SUM="49097459eb06bb624ff3d09f959d0423"

	echo
	echo "Running Tremolo decoder test"
	if [ ! -f ${TEST_FILE} ]; then
		echo "ERROR: Tremolo test file ${TEST_FILE} does not exist"
		echo "Tremolo decoder test: FAILED"
		echo "[audio_codec_tremolo]: test failed"
		return 1
	fi
	if [ "${VERBOSE}" -eq "1" ]; then
		libvorbisidec_test ${TEST_FILE} ${OUT_FILE}
	else
		libvorbisidec_test ${TEST_FILE} ${OUT_FILE} > /dev/null 2>&1
	fi
	if [ "$?" -ne "0" ]; then
		echo "ERROR: Tremolo decoder test returned error"
		echo "Tremolo decoder test: FAILED"
		echo "[audio_codec_tremolo]: test failed"
		return 1
	fi

	echo "Checking MD5SUM of output file"
	local MD5SUM="$(func_md5 ${OUT_FILE})"
	MD5SUM=${MD5SUM%% *}
	rm ${OUT_FILE}
	if [[ "${MD5SUM}" == "${EXPECTED_MD5SUM}" ]]; then
		echo "Tremolo decoder test: PASSED"
		echo "[audio_codec_tremolo]: test passed"
	else
		echo "ERROR: incorrect MD5SUM '${MD5SUM}' (expected '${EXPECTED_MD5SUM}')"
		echo "Tremolo decoder test: FAILED"
		echo "[audio_codec_tremolo]: test failed"
		return 1
	fi
}

run_speech_codec()
{
	if [ "$#" -ne "6" ]; then
		return 1
	fi

	local IS_ENCODE="${1}"
	local TAG="${2}"
	local NAME="${3}"
	local DATA_DIR="${4}"
	local MD5SUM_FILE="${5}"
	local RUN="${6}"
	local OUT_FILE="/data/local/tmp/speech-codec-test.out"

	echo
	echo "${TAG}: Running ${NAME}"
	if [ ! -f ${MD5SUM_FILE} ]; then
		echo "${TAG}: ERROR: MD5SUM file '${MD5SUM_FILE}' does not exist"
		echo "${TAG}: ${NAME}: FAILED"
		echo "[${TAG}]: test failed"
		return 1
	fi

	if [ "${IS_ENCODE}" -eq "1" ]; then
		echo -n "${TAG}: Encoding and verifying output"
	else
		echo -n "${TAG}: Decoding and verifying output"
	fi

	while read -r LINE
	do
		if [[ "${LINE:0:1}" == "#" ]]; then
			continue
		fi

		echo -n "."
		TEST_FILE="${LINE%%['\t' ]*}"
		if [ -z "${TEST_FILE}" ]; then
			echo "${TAG}: ERROR: Invalid test file/MD5SUM pair"
			echo "${TAG}: ${NAME}: FAILED"
			echo "[${TAG}]: test failed"
			return 1
		fi

		# Remove the test file, leaving the MD5SUMs
		LINE="${LINE#"${TEST_FILE}"}"

		TEST_FILE="${DATA_DIR}/${TEST_FILE}"
		if [ ! -f ${TEST_FILE} ]; then
			echo "${TAG}: ERROR: test file '${TEST_FILE}' does not exist"
			echo "${TAG}: ${NAME}: FAILED"
			echo "[${TAG}]: test failed"
			return 1
		fi

		local INDEX=0
		local result=true
		for EXPECTED_MD5SUM in ${LINE}; do
			local cmd=""
			if [ "${IS_ENCODE}" -eq "1" ]; then
				cmd="${RUN} +M${INDEX} ${TEST_FILE} ${OUT_FILE}"
				if [ "${VERBOSE}" -eq "1" ]; then
					${cmd}
				else
					${cmd} > /dev/null 2>&1
				fi
			else
				cmd="${RUN} ${TEST_FILE} ${OUT_FILE}"
				if [ "${VERBOSE}" -eq "1" ]; then
					${cmd}
				else
					${cmd} > /dev/null 2>&1
				fi
			fi
			if [ "$?" -ne "0" ]; then
				echo
				echo "${TAG}: ${cmd}"
				echo "${TAG}: ERROR: ${NAME} returned error"
				result=false
				continue
			fi

			local MD5SUM="$(func_md5 ${OUT_FILE})"
			MD5SUM="${MD5SUM%% *}"
			if [[ "${MD5SUM}" != "${EXPECTED_MD5SUM}" ]]; then
				echo
				echo "${TAG}: ${cmd}"
				echo "${TAG}: ERROR: incorrect MD5SUM '${MD5SUM}' (expected '${EXPECTED_MD5SUM}')"
				result=false
				continue
			fi

			((INDEX++))
		done
	done < ${MD5SUM_FILE}
	echo "done"

	if [ -f ${OUT_FILE} ]; then
		rm ${OUT_FILE}
	fi

	if $result; then
		echo "${TAG}: ${NAME}: PASSED"
		echo "[${TAG}]: test passed"
	else
		echo "${TAG}: ${NAME}: FAILED"
		echo "[${TAG}]: test failed"
	fi
}

run_speech_codec_amrnb_dec()
{
	local TAG="speech_codec_amrnb_dec"
	local NAME="AMR NB decoder test"
	local DATA_DIR="/data/linaro-android-userspace-test/speech-codec/amrnb"
	local MD5SUM_FILE="${DATA_DIR}/MD5SUM.dec"

	run_speech_codec 0 "${TAG}" "${NAME}" "${DATA_DIR}" "${MD5SUM_FILE}" "libstagefright_amrnbdec_test"
	return $?
}

run_speech_codec_amrnb_enc()
{
	local TAG="speech_codec_amrnb_enc"
	local NAME="AMR NB encoder test"
	local DATA_DIR="/data/linaro-android-userspace-test/speech-codec/amrnb"
	local MD5SUM_FILE="${DATA_DIR}/MD5SUM.enc"

	run_speech_codec 1 "${TAG}" "${NAME}" "${DATA_DIR}" "${MD5SUM_FILE}" "libstagefright_amrnbenc_test"
	return $?
}

run_speech_codec_amrwb_dec()
{
	local TAG="speech_codec_amrwb_dec"
	local NAME="AMR WB decoder test"
	local DATA_DIR="/data/linaro-android-userspace-test/speech-codec/amrwb"
	local MD5SUM_FILE="${DATA_DIR}/MD5SUM.dec"

	run_speech_codec 0 "${TAG}" "${NAME}" "${DATA_DIR}" "${MD5SUM_FILE}" "libstagefright_amrwbdec_test"
	return $?
}

run_speech_codec_amrwb_enc()
{
	local TAG="speech_codec_amrwb_enc"
	local NAME="AMR WB encoder test"
	local DATA_DIR="/data/linaro-android-userspace-test/speech-codec/amrwb"
	local MD5SUM_FILE="${DATA_DIR}/MD5SUM.enc"

	run_speech_codec 1 "${TAG}" "${NAME}" "${DATA_DIR}" "${MD5SUM_FILE}" "libstagefright_amrwbenc_test"
	return $?
}

run_video_codec_h264_dec()
{
	local TAG="video_codec_h264_dec"
	local NAME="H.264 decoder test"
	local DATA_DIR="/data/linaro-android-userspace-test/video-codec/h264"
	local MD5SUM_FILE="${DATA_DIR}/MD5SUM.dec"
	local RUN="libstagefright_h264dec_test"
	local OUT_FILE="/data/local/tmp/video-codec-test.out"

	echo
	echo "${TAG}: Running ${NAME}"
	if [ ! -f ${MD5SUM_FILE} ]; then
		echo "${TAG}: ERROR: MD5SUM file '${MD5SUM_FILE}' does not exist"
		echo "${TAG}: ${NAME}: FAILED"
		echo "[${TAG}]: test failed"
		return 1
	fi

	echo -n "${TAG}: Decoding and verifying output"

	local TEST_FILE=""
	local EXPECTED_MD5SUM=""
	local LINE=0
	while read -r TEST_FILE EXPECTED_MD5SUM
	do
		((LINE++))

		# Skip comment or empty lines
		if [[ "${TEST_FILE:0:1}" == "#" ]] || [ -z "${TEST_FILE}" ]; then
			continue
		fi

		echo -n "."
		if [ -z "${EXPECTED_MD5SUM}" ]; then
			echo "${TAG}: ERROR: invalid MD5SUM entry (${MD5SUM_FILE}:${LINE})"
			echo "${TAG}: ${NAME}: FAILED"
			echo "[${TAG}]: test failed"
			return 1
		fi

		TEST_FILE="${DATA_DIR}/${TEST_FILE}"
		if [ ! -f ${TEST_FILE} ]; then
			echo "${TAG}: ERROR: test file '${TEST_FILE}' does not exist"
			echo "${TAG}: ${NAME}: FAILED"
			echo "[${TAG}]: test failed"
			return 1
		fi

		if [ "${VERBOSE}" -eq "1" ]; then
			${RUN} -O${OUT_FILE} ${TEST_FILE}
		else
			${RUN} -O${OUT_FILE} ${TEST_FILE} > /dev/null 2>&1
		fi

		if [ "$?" -ne "0" ]; then
			echo
			echo "${TAG}: ERROR: ${NAME} returned error for ${MD5SUM_FILE}:${LINE}"
			echo "${TAG}: ${NAME}: FAILED"
			echo "[${TAG}]: test failed"
			return 1
		fi

		local MD5SUM="$(func_md5 ${OUT_FILE})"
		MD5SUM="${MD5SUM%% *}"
		if [[ "${MD5SUM}" != "${EXPECTED_MD5SUM}" ]]; then
			echo
			echo "${TAG}: ERROR: incorrect MD5SUM '${MD5SUM}' (expected '${EXPECTED_MD5SUM}')"
			echo "${TAG}: ${NAME}: FAILED"
			echo "[${TAG}]: test failed"
			return 1
		fi
	done < ${MD5SUM_FILE}
	echo "done"

	if [ -f ${OUT_FILE} ]; then
		rm ${OUT_FILE}
	fi

	echo "${TAG}: ${NAME}: PASSED"
	echo "[${TAG}]: test passed"
	return $?
}

run_video_codec_h264_enc()
{
	local TAG="video_codec_h264_enc"
	local NAME="H.264 encoder test"
	local DATA_DIR="/data/linaro-android-userspace-test/video-codec/h264"
	local MD5SUM_FILE="${DATA_DIR}/MD5SUM.enc"
	local RUN="libstagefright_h264enc_test"
	local OUT_FILE="/data/local/tmp/video-codec-test.out"

	echo
	echo "${TAG}: Running ${NAME}"
	if [ ! -f ${MD5SUM_FILE} ]; then
		echo "${TAG}: ERROR: MD5SUM file '${MD5SUM_FILE}' does not exist"
		echo "${TAG}: ${NAME}: FAILED"
		echo "[${TAG}]: test failed"
		return 1
	fi

	echo -n "${TAG}: Encoding and verifying output"

	local TEST_FILE=""
	local OUT_WIDTH=""
	local OUT_HEIGHT=""
	local OUT_FRAMERATE=""
	local OUT_BITRATE=""
	local EXPECTED_MD5SUM=""
	local LINE=0
	local result=true
	while read -r TEST_FILE OUT_WIDTH OUT_HEIGHT OUT_FRAMERATE OUT_BITRATE EXPECTED_MD5SUM
	do
		((LINE++))

		# Skip comment or empty lines
		if [[ "${TEST_FILE:0:1}" == "#" ]] || [ -z "${TEST_FILE}" ]; then
			continue
		fi

		echo -n "."

		if [ -z "${OUT_WIDTH}" -o -z "${OUT_HEIGHT}" -o -z "${OUT_FRAMERATE}" -o -z "${OUT_BITRATE}" -o -z "${EXPECTED_MD5SUM}" ]; then
			echo "${TAG}: ERROR: invalid MD5SUM entry (${MD5SUM_FILE}:${LINE})"
			echo "${TAG}: ${NAME}: FAILED"
			echo "[${TAG}]: test failed"
			return 1
		fi

		TEST_FILE="${DATA_DIR}/${TEST_FILE}"
		if [ ! -f ${TEST_FILE} ]; then
			echo "${TAG}: ERROR: test file '${TEST_FILE}' does not exist"
			echo "${TAG}: ${NAME}: FAILED"
			echo "[${TAG}]: test failed"
			return 1
		fi
		local cmd="${RUN} ${TEST_FILE} ${OUT_FILE} ${OUT_WIDTH} ${OUT_HEIGHT} ${OUT_FRAMERATE} ${OUT_BITRATE}"
		if [ "${VERBOSE}" -eq "1" ]; then
			$cmd
		else
			${cmd} > /dev/null 2>&1
		fi

		if [ "$?" -ne "0" ]; then
			echo
			echo "${TAG}: ${cmd}"
			echo "${TAG}: ERROR: ${NAME} returned error for ${MD5SUM_FILE}:${LINE}"
			result=false
			continue
		fi

		local MD5SUM="$(func_md5 ${OUT_FILE})"
		MD5SUM="${MD5SUM%% *}"
		if [[ "${MD5SUM}" != "${EXPECTED_MD5SUM}" ]]; then
			echo
			echo "${TAG}: ${cmd}"
			echo "${TAG}: ERROR: incorrect MD5SUM '${MD5SUM}' (expected '${EXPECTED_MD5SUM}')"
			result=false
			continue
		fi
	done < ${MD5SUM_FILE}
	echo "done"

	if [ -f ${OUT_FILE} ]; then
		rm ${OUT_FILE}
	fi

	if ${result}; then
		echo "${TAG}: ${NAME}: PASSED"
		echo "[${TAG}]: test passed"
	else
		echo "${TAG}: ${NAME}: FAILED"
		echo "[${TAG}]: test failed"
	fi
	return 0
}

run_video_codec_h263_dec()
{
	local TAG="video_codec_h263_dec"
	local NAME="H.263 decoder test"
	local DATA_DIR="/data/linaro-android-userspace-test/video-codec/h263"
	local MD5SUM_FILE="${DATA_DIR}/MD5SUM.dec"
	local RUN="libstagefright_m4vh263dec_test"
	local OUT_FILE="/data/local/tmp/video-codec-test.out"

	echo
	echo "${TAG}: Running ${NAME}"
	if [ ! -f ${MD5SUM_FILE} ]; then
		echo "${TAG}: ERROR: MD5SUM file '${MD5SUM_FILE}' does not exist"
		echo "${TAG}: ${NAME}: FAILED"
		echo "[${TAG}]: test failed"
		return 1
	fi

	echo -n "${TAG}: Decoding and verifying output"

	local TEST_FILE=""
	local OUT_WIDTH=""
	local OUT_HEIGHT=""
	local EXPECTED_MD5SUM=""
	local LINE=0
	while read -r TEST_FILE OUT_WIDTH OUT_HEIGHT EXPECTED_MD5SUM
	do
		((LINE++))

		# Skip comment or empty lines
		if [[ "${TEST_FILE:0:1}" == "#" ]] || [ -z "${TEST_FILE}" ]; then
			continue
		fi

		echo -n "."

		if [ -z "${OUT_WIDTH}" -o -z "${OUT_HEIGHT}" -o -z "${EXPECTED_MD5SUM}" ]; then
			echo "${TAG}: ERROR: invalid MD5SUM entry (${MD5SUM_FILE}:${LINE})"
			echo "${TAG}: ${NAME}: FAILED"
			echo "[${TAG}]: test failed"
			return 1
		fi

		TEST_FILE="${DATA_DIR}/${TEST_FILE}"
		if [ ! -f ${TEST_FILE} ]; then
			echo "${TAG}: ERROR: test file '${TEST_FILE}' does not exist"
			echo "${TAG}: ${NAME}: FAILED"
			echo "[${TAG}]: test failed"
			return 1
		fi

		if [ "${VERBOSE}" -eq "1" ]; then
			${RUN} ${TEST_FILE} ${OUT_FILE} ${OUT_WIDTH} ${OUT_HEIGHT}
		else
			${RUN} ${TEST_FILE} ${OUT_FILE} ${OUT_WIDTH} ${OUT_HEIGHT} > /dev/null 2>&1
		fi

		if [ "$?" -ne "0" ]; then
			echo
			echo "${TAG}: ERROR: ${NAME} returned error for ${MD5SUM_FILE}:${LINE}"
			echo "${TAG}: ${NAME}: FAILED"
			echo "[${TAG}]: test failed"
			return 1
		fi

		local MD5SUM="$(func_md5 ${OUT_FILE})"
		MD5SUM="${MD5SUM%% *}"
		if [[ "${MD5SUM}" != "${EXPECTED_MD5SUM}" ]]; then
			echo
			echo "${TAG}: ERROR: incorrect MD5SUM '${MD5SUM}' (expected '${EXPECTED_MD5SUM}')"
			echo "${TAG}: ${NAME}: FAILED"
			echo "[${TAG}]: test failed"
			return 1
		fi
	done < ${MD5SUM_FILE}
	echo "done"

	if [ -f ${OUT_FILE} ]; then
		rm ${OUT_FILE}
	fi

	echo "${TAG}: ${NAME}: PASSED"
	echo "[${TAG}]: test passed"
	return $?
}

run_video_codec_h263_enc()
{
	local TAG="video_codec_h263_enc"
	local NAME="H.263 encoder test"
	local DATA_DIR="/data/linaro-android-userspace-test/video-codec/h263"
	local MD5SUM_FILE="${DATA_DIR}/MD5SUM.enc"
	local RUN="libstagefright_m4vh263enc_test"
	local OUT_FILE="/data/local/tmp/video-codec-test.out"

	echo
	echo "${TAG}: Running ${NAME}"
	if [ ! -f ${MD5SUM_FILE} ]; then
		echo "${TAG}: ERROR: MD5SUM file '${MD5SUM_FILE}' does not exist"
		echo "${TAG}: ${NAME}: FAILED"
		echo "[${TAG}]: test failed"
		return 1
	fi

	echo -n "${TAG}: Encoding and verifying output"

	local TEST_FILE=""
	local OUT_WIDTH=""
	local OUT_HEIGHT=""
	local OUT_FRAMERATE=""
	local OUT_BITRATE=""
	local EXPECTED_MD5SUM=""
	local LINE=0
	while read -r TEST_FILE OUT_WIDTH OUT_HEIGHT OUT_FRAMERATE OUT_BITRATE EXPECTED_MD5SUM
	do
		((LINE++))

		# Skip comment or empty lines
		if [[ "${TEST_FILE:0:1}" == "#" ]] || [ -z "${TEST_FILE}" ]; then
			continue
		fi

		echo -n "."
		if [ -z "${OUT_WIDTH}" -o -z "${OUT_HEIGHT}" -o -z "${OUT_FRAMERATE}" -o -z "${OUT_BITRATE}" -o -z "${EXPECTED_MD5SUM}" ]; then
			echo "${TAG}: ERROR: invalid MD5SUM entry (${MD5SUM_FILE}:${LINE})"
			echo "${TAG}: ${NAME}: FAILED"
			echo "[${TAG}]: test failed"
			return 1
		fi

		TEST_FILE="${DATA_DIR}/${TEST_FILE}"
		if [ ! -f ${TEST_FILE} ]; then
			echo "${TAG}: ERROR: test file '${TEST_FILE}' does not exist"
			echo "${TAG}: ${NAME}: FAILED"
			echo "[${TAG}]: test failed"
			return 1
		fi

		if [ "${VERBOSE}" -eq "1" ]; then
			${RUN} ${TEST_FILE} ${OUT_FILE} mpeg4 ${OUT_WIDTH} ${OUT_HEIGHT} ${OUT_FRAMERATE} ${OUT_BITRATE}
		else
			${RUN} ${TEST_FILE} ${OUT_FILE} mpeg4 ${OUT_WIDTH} ${OUT_HEIGHT} ${OUT_FRAMERATE} ${OUT_BITRATE} > /dev/null 2>&1
		fi

		if [ "$?" -ne "0" ]; then
			echo
			echo "${TAG}: ERROR: ${NAME} returned error for ${MD5SUM_FILE}:${LINE}"
			echo "${TAG}: ${NAME}: FAILED"
			echo "[${TAG}]: test failed"
			return 1
		fi

		local MD5SUM="$(func_md5 ${OUT_FILE})"
		MD5SUM="${MD5SUM%% *}"
		if [[ "${MD5SUM}" != "${EXPECTED_MD5SUM}" ]]; then
			echo
			echo "${TAG}: ERROR: incorrect MD5SUM '${MD5SUM}' (expected '${EXPECTED_MD5SUM}')"
			echo "${TAG}: ${NAME}: FAILED"
			echo "[${TAG}]: test failed"
			echo "${MD5SUM}" >> /sdcard/md5.txt
			return 1
		fi
	done < ${MD5SUM_FILE}
	echo "done"

	if [ -f ${OUT_FILE} ]; then
		rm ${OUT_FILE}
	fi

	echo "${TAG}: ${NAME}: PASSED"
	echo "[${TAG}]: test passed"
	return $?
}

run_tests() {
	local RET=0
	for TEST in $TESTS;
	do
		if [[ "${ALL_TESTS}" == *"${TEST}"* ]]; then
			# Function names follow the naming convention of:
			# run_<test_name>
			run_${TEST}
			RET=$(( RET + $? ))
		else
			echo
			echo "Unrecognized test '${TEST}'"
			usage
			RET=$(( RET + 1 ))
			break
		fi
	done
	return ${RET}
}

# Terse output by default
VERBOSE=0

TESTS=""

while getopts "hvt:" OPT
do
	case $OPT in
	h)
		usage
		exit 1
		;;
	t)
		TESTS=$OPTARG
		;;
	v)
		VERBOSE=1
		;;
	*)
		usage
		exit
	esac
done

if [ -z "${TESTS}" ]; then
	# Run all tests by default
	TESTS="${ALL_TESTS}"
	echo "Running all tests"
else
	# Expand out any batch tests
	TESTS="${TESTS//${ALL_AUDIO_CODECS_OPT}/${ALL_AUDIO_CODECS}}"
	TESTS="${TESTS//${ALL_SPEECH_CODECS_OPT}/${ALL_SPEECH_CODECS}}"
	TESTS="${TESTS//${ALL_VIDEO_CODECS_OPT}/${ALL_VIDEO_CODECS}}"
	TESTS="${TESTS//${ALL_CODECS_OPT}/${ALL_CODECS}}"
	TESTS="${TESTS//${ALL_TESTS_OPT}/${ALL_TESTS}}"
fi

run_tests
return $?
