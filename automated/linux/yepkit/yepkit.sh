#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2019 Linaro Ltd.

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
YKUSHCMD=ykushcmd

SKIP_INSTALL="false"
SERIAL_NUM=""
LIST="false"
PORT_UP=""
PORT_DOWN=""
PORT_DEVICE=""

RESULT=pass

usage() {
	echo "\
	Usage: $0
		[-n <serial num>] [-l <true|false>] [-p <port device>] [-d 1|2|3|a] [-u 1|2|3|a] [-s <true|false>]

	By default, this script will install /usr/bin/ykushcmd and do nothing else. The following parameters
	can be provided to modify the behaviour to the library:

	-n <serial num>
		The serial number of the YepKit device to use. Leave blank if you do not
		know the serial number and there is only one YepKit device installed

	-l <true|false>
		List attached Yepkit YKUSH boards. The serial number of each
		board attached to the host will be displayed.

	-d <1|2|3|a>
		Power Down/Off downstream port with the number provided.
		If a is provided as the port number then all ports
		will be switched.

	-u <1|2|3|a>
		Power Up/On downstream port with the number provided.
		If a is provided as the port number then all ports
		will be switched.

	-g <1|2|3>
		Get state of downstream port.

	-p <port device>
		In the case of a port being powered up, check the device appears.
		In the case of a port being powered down, check the device is removed.

	-s <true|false>
		Tell the test to skip installation of dependencies, or not.
		If ykushcmd is not present, the repo will be cloned, the command
		built and installed.
	"
}

while getopts "d:g:h:l:n:p:s:u:" opts; do
	case "$opts" in
		d) PORT_DOWN="${OPTARG,,}" ;;
		g) PORT_GET="${OPTARG,,}" ;;
		l) LIST="${OPTARG,,}" ;;
		n) SERIAL_NUM="${OPTARG}";
		   if [ "${SERIAL_NUM}" != "" ]; then
			SERIAL_NUM_OPT="-s ${SERIAL_NUM}"
		   fi
		   ;;
		p) PORT_DEVICE="${OPTARG}" ;;
		u) PORT_UP="${OPTARG,,}" ;;

		s) SKIP_INSTALL="${OPTARG,,}" ;;
		h|*) usage ; exit 1 ;;
	esac
done


install() {
	if [ "${SKIP_INSTALL}" = "true" ]; then
		return # we don't want to report skip results
	else
		if [[ $(which "${YKUSHCMD}") ]]; then
			echo "A local ${YKUSHCMD} exists, use it"
			return # we don't want to report skip results
		else
			clonedir=$(mktemp -d "/tmp/ykush.XXXXX")
			git clone https://github.com/Yepkit/ykush "${clonedir}"
			if [ -e "${clonedir}" ]; then
				pushd "${clonedir}" > /dev/null 2>&1 || return
				make clean
				make
				./install.sh
				popd > /dev/null 2>&1 || return
			else
				echo "ERROR: ykush repo doesn't exist"
				RESULT=fail
			fi
			rm -rf "${clonedir}"
		fi

		# after all that, if the command still doesn't exist, it's an error
		if [[ ! $(which "${YKUSHCMD}") ]]; then
			echo "ERROR: ${YKUSHCMD} doesn't exist"
			RESULT=fail
			exit 1
		fi
	fi
	echo yepkit-install "${RESULT}" | tee -a "${RESULT_FILE}"
}

device_exists () {
	local device
	device="$1"

	if [[ -e ${device} ]]; then
		echo 1
	else
		echo 0
	fi
}

wait_for_device () {
	local device
	local removed
        local retries
	local check
	local extra_text

	device="${1}"
	removed="${2,,}"
        retries="20"
	check="1"
	extra_text=""

	if [ "${removed}" != "" ]; then
		check="0"
		extra_text=" to be removed"
	fi
	echo -n "Waiting for ${device}${extra_text}: "
        for ((i=0;i<retries;++i)); do
		local exists
		exists=$(device_exists "${device}")
		if [[ "${exists}" = "${check}" ]]; then
			echo "done"
			sleep 0.5 # allow the device some time to settle after being plugged in
			return
		fi
		echo -n "."
		sleep 0.5
	done
	echo "failed"
}

ykush_do() {
	local cmd
	local port
	cmd="$1"
	port="$2"

	"${YKUSHCMD}" "${cmd}" "${port}" "${SERIAL_NUM_OPT}"
}

ykush_list() {
	RESULT=pass
	if [ "${LIST}" == "true" ]; then
		echo "yepkit: List available YKUSH Yepkit devices"
		ykush_do -l || RESULT=fail
	fi
	echo yepkit-list-command "${RESULT}" | tee -a "${RESULT_FILE}"
}

ykush_up() {
	local port
	port=$1
	RESULT=pass

	if [ "${port}" = "" ]; then
		return
	fi

	if [ "${PORT_DEVICE}" != "" ]; then
		local exists
		exists=$(device_exists "${PORT_DEVICE}")
		if [[ "${exists}" = "1" ]]; then
			RESULT=fail
		fi
		echo yepkit-up-device-not-exists "${RESULT}" | tee -a "${RESULT_FILE}"
	fi

	if [ "${RESULT}" == "pass" ]; then
		if [[ "${port}" != "" && "${port}" != "none" ]]; then
			echo "yepkit: setting port ${port} up"
			ykush_do -u "${port}"
		fi
		echo yepkit-up-command "${RESULT}" | tee -a "${RESULT_FILE}"
	fi

	if [ "${RESULT}" == "pass" ]; then
		if [ "${PORT_DEVICE}" != "" ]; then
			local exists
			wait_for_device "${PORT_DEVICE}"
			exists=$(device_exists "${PORT_DEVICE}")
			if [ "${exists}" == "0" ]; then
				RESULT=fail
			fi
			echo yepkit-up-device-created "${RESULT}" | tee -a "${RESULT_FILE}"
		fi
	fi
}

ykush_down() {
	local port
	port=$1
	RESULT=pass

	if [ "${port}" = "" ]; then
		return
	fi

	if [ "${PORT_DEVICE}" != "" ]; then
		local exists
		exists=$(device_exists "${PORT_DEVICE}")
		if [[ "${exists}" = "0" ]]; then
			RESULT=fail
		fi
		echo yepkit-down-device-exists "${RESULT}" | tee -a "${RESULT_FILE}"
	fi

	if [ "${RESULT}" == "pass" ]; then
		if [[ "${port}" != "" && "${port}" != "none" ]]; then
			echo "yepkit: setting port ${port} down"
			ykush_do -d "${port}"
		fi
		echo yepkit-down-command "${RESULT}" | tee -a "${RESULT_FILE}"
	fi

	if [ "${RESULT}" == "pass" ]; then
		if [ "${PORT_DEVICE}" != "" ]; then
			local exists
			wait_for_device "${PORT_DEVICE}" removed
			exists=$(device_exists "${PORT_DEVICE}")
			if [ "${exists}" == "1" ]; then
				RESULT=fail
			fi
			echo yepkit-down-device-removed "${RESULT}" | tee -a "${RESULT_FILE}"
		fi
	fi
}


ykush_get() {
	local port
	port=$1
	RESULT=pass

	if [ "${port}" = "" ]; then
		return
	fi

	if [[ "${port}" != "" && "${port}" != "none" ]]; then
		echo "yepkit: getting the status of port ${port}"
		ykush_do -g "${port}"
	fi
	echo yepkit-get-command "${RESULT}" | tee -a "${RESULT_FILE}"
}

create_out_dir "${OUTPUT}"
install
RESULT=pass

ykush_list "${LIST}"
ykush_up "${PORT_UP}"
ykush_down "${PORT_DOWN}"
ykush_get "${PORT_GET}"
