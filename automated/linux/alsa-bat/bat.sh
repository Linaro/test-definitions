#!/bin/sh -e
# shellcheck disable=SC1091

OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"

. ../../lib/sh-test-lib

create_out_dir "${OUTPUT}"

PARAMS=

if [ "${TST_CARD}" != "" ]; then
	PARAMS="${PARAMS} -D${TST_CARD}"
fi

if [ "${TST_CHANNELS}" != "" ]; then
	PARAMS="${PARAMS} -c${TST_CHANNELS}"
fi

if [ "${TST_PLAYBACK}" != "" ]; then
	PARAMS="${PARAMS} -P${TST_PLAYBACK}"
fi

if [ "${TST_CAPTURE}" != "" ]; then
	PARAMS="${PARAMS} -C${TST_CAPTURE}"
fi

if [ "${TST_FORMAT}" != "" ]; then
	PARAMS="${PARAMS} -f${TST_FORMAT}"
fi

if [ "${TST_RATE}" != "" ]; then
	PARAMS="${PARAMS} -r${TST_RATE}"
fi

if [ "${TST_LENGTH}" != "" ]; then
	PARAMS="${PARAMS} -n${TST_LENGTH}"
fi

if [ "${TST_SIGMA_K}" != "" ]; then
	PARAMS="${PARAMS} -k${TST_SIGMA_K}"
fi

if [ "${TST_FREQ}" != "" ]; then
	PARAMS="${PARAMS} -F${TST_FREQ}"
fi

# Debian installs as alsabat due to name collisions
if [ "$(command -v alsabat)" != "" ]; then
	BAT=alsabat
elif [ "$(command -v bat)" != "" ]; then
	BAT=bat
fi

if [ "${BAT}" = "" ]; then
	echo Unable to find BAT
	exit 1
fi

TEST_NAME="$(echo "bat${PARAMS}" | sed 's/ /_/g' | sed 's/-//g')"

# Return code 0 for pass, other codes for various fails
if ${BAT} ${PARAMS} --log=${OUTPUT}/${TEST_NAME}.log ; then
	R=pass
else
	R=fail
fi

echo ${TEST_NAME} ${R} >> ${RESULT_FILE}

../../utils/send-to-lava.sh ${RESULT_FILE}
