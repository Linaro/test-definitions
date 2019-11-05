#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2019 Linaro Ltd.

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"

usage() {
	echo "\
	Usage: $0
			     [-t </dev/ttyX>] [-r </dev/ttyX]

	<t>:
		The transmit UART used for the loopback tests
	<r>:
		The receive UART used for the loopback tests

	This test will perform loopback transmission between two UARTs,
	using various baud rates, parity and stop bit settings.
	"
}


while getopts "t:r:h" opts; do
    case "$opts" in
        t) TXUART="${OPTARG}" ;;
        r) RXUART="${OPTARG}" ;;
        h|*) usage ; exit 1 ;;
    esac
done

param_err=0
if [[ -z "${TXUART}" ]]; then
	echo "ERROR: you must use option -t to specify TXUART"
	param_err=1
fi

if [[ -z "${RXUART}" ]]; then
	echo "ERROR: you must use option -r to specify RXUART"
	param_err=1
fi

if [[ ! param_err -eq 0 ]]; then
	usage
	exit 1
fi

char_device_exists () {
	local device=$1

	if [[ -c ${device} ]]; then
		echo true
	else
		echo false
	fi
}

wait_for_device () {
	local device=$1
        local retries=20

	if [[ -z ${device} ]]; then
		echo "You must specifiy a valid device"
		exit 1
	fi

	echo -n "Waiting for ${device}: "
        for ((i=0;i<retries;++i)); do
		local exists
		exists=$(char_device_exists "${device}")
		if [[ "${exists}" == "true" ]]; then
			echo "done"
			sleep 0.5 # allow the device some time to settle after being plugged in
			return
		fi
		echo -n "."
		sleep 0.5
	done
	echo "failed"
	echo "uart-loopback fail" >> "${RESULT_FILE}"
	exit 1
}

test_one () {
	LENGTH=$1
	detect_abi
	# shellcheck disable=SC2154
	case "$abi" in
	  armeabi|arm64|x86_64) ;;
	  *) warn_msg "Unsupported architecture"; exit 1 ;;
	esac

	DIR="$( dirname "$0" )"
	if ! "${DIR}"/uart-loopback."${abi}" -o "${TXUART}" -i "${RXUART}" -s "${LENGTH}" -r
	then
		ERRORS=$((ERRORS+1));
	fi
}

# Test transfers of lengths that typically throw problems
test_one_cfg () {
	local settings="$*"
	local errors="${ERRORS}"

	# shellcheck disable=SC2086
	stty -F "${TXUART}" ${settings}
	# shellcheck disable=SC2086
	stty -F "${RXUART}" ${settings}

	for length in $(seq 1 33); do
		test_one "${length}"
	done

	test_one 4095
	test_one 4096
	test_one 4097

	if [ "${errors}" = "${ERRORS}" ]; then
		echo " pass"
	else
		echo " fail"
	fi
}

uart-loopback () {
	# Note that we specify the _changes_ to the tty settings, so don't comment one out!
	baudrates=(9600 38400 115200 230400)
	for baud in "${baudrates[@]}" ;
	do
		echo -n "${baud}:8n1:raw"
		test_one_cfg "${baud} -parenb -cstopb -crtscts cs8 -ignbrk -brkint  -parmrk -istrip -inlcr -igncr -icrnl -ixon -opost -echo -echonl -icanon -isig -iexten"

		echo -n "${baud}:8o1"
		test_one_cfg "parenb parodd"

		echo -n "${baud}:8e1"
		test_one_cfg "-parodd"

		echo -n "${baud}:8n2"
		test_one_cfg "-parenb cstopb"

		echo -n "${baud}:8n1:CTS/RTS"
		test_one_cfg "-cstopb crtscts"

		# This is the same as the first test, putting the UART back into 115200
		echo -n "${baud}:8n1:raw"
		test_one_cfg "-crtscts"
	done

	echo
	echo "Tests complete with ${ERRORS} Errors."
}

loopback_test () {
	local logfile
	logfile=$(mktemp "/tmp/uart-loopback.log.XXXXXXXXXXXX")

	echo "Testing data transfer from ${TXUART} to ${RXUART}" | tee "${logfile}"
	uart-loopback "${TXUART}" "${RXUART}" | tee -a "${logfile}"
	sed -i 's/\.//g' "${logfile}"
	grep -e "pass" -e "fail" "${logfile}" >> "${RESULT_FILE}"
}

create_out_dir "${OUTPUT}"
wait_for_device "${TXUART}"
wait_for_device "${RXUART}"
loopback_test
