#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2019 Linaro Ltd.

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"

PARTDEV=""
PARTNAME=""
DEVICE=""
DEVNAME=""

SKIP_INSTALL="false"
FORMAT_DEVICE="false"

MOUNT_DIR=$(mktemp -d "/tmp/block-device.XXXXX")
TMPFILE=$(mktemp "/tmp/10M.XXXXX")
RESULT=pass

usage() {
	echo "\
	Usage: $0
		     [-d </dev/sdXN>]
		     [-f <true|false>]
		     [-s <true|false>]

	-d </dev/sdXN>
		This is the block device to be tested, eg. /dev/sda1.
		It should be a partition, not a raw block device
	-f <true|false>
		This will erase the device and create a new partition table
		with a single ext4 partition on it.
	-s <true|false>
		Tell the test to skip installation of dependencies, or not

	This test will perform tests on a block device.
	"
}

while getopts "d:f:s:h" opts; do
	case "$opts" in
		d) PARTDEV="${OPTARG}";
		   PARTNAME=$(basename -- "${PARTDEV}");
		   DEVICE=${PARTDEV/%[[:digit:]]/}
		   DEVNAME=$(basename -- "${DEVICE}")
		   ;;
		f) FORMAT_DEVICE="${OPTARG,,}" ;;
		s) SKIP_INSTALL="${OPTARG,,}" ;;
		h|*) usage ; exit 1 ;;
	esac
done

install() {
	if [ "${SKIP_INSTALL}" = "true" ]; then
		info_msg "Skip installing dependencies"
	else
		# install dependencies
		dist=
		dist_name
		case "${dist}" in
			debian|ubuntu)
				pkgs="bonnie++"
				install_deps "${pkgs}" "${SKIP_INSTALL}"
				;;
			fedora|centos)
				pkgs="bonnie++"
				install_deps "${pkgs}" "${SKIP_INSTALL}"
				;;
			# When we don't have a package manager
			# Assume dependencies pre-installed
			*)
				echo "Unsupported distro: ${dist}! Package installation skipped!"
				;;
		esac
	fi
}

block_device_exists () {
	local device=$1

	if [[ -b ${device} ]]; then
		echo true
	else
		echo false
	fi
}

wait_for_device () {
	local device=$1
	local retries=20

	echo -n "Waiting for ${device}: "
        for ((i=0;i<retries;++i)); do
		local exists
		exists=$(block_device_exists "${device}")
		if [[ "${exists}" == "true" ]]; then
			echo "done"
			echo "block-device-${DEVNAME}-present pass" | tee -a "${RESULT_FILE}"
			sleep 0.5 # allow the device some time to settle after being plugged in
			return
		fi
		echo -n "."
		sleep 0.5
	done
	echo "failed"
	echo "block-device-preset-${DEVNAME} fail" | tee -a "${RESULT_FILE}"
	exit 1
}

device_mounted() {
	local dev
	dev="$1"
	if grep -qs "${dev}" /proc/mounts; then
		echo "1"
	else
		echo "0"
	fi
}

format_device() {
	if [ "${RESULT}" != "fail" ] && [ "${FORMAT_DEVICE}" = "true" ] ; then
		local mounted
		mounted=$(device_mounted "${PARTDEV}")
		if [ "${mounted}" = "1" ]; then
			RESULT=fail
			echo "block-device-${DEVNAME}-not-mounted ${RESULT}" | tee -a "${RESULT_FILE}"
			return
		fi
		echo "block-device-${DEVNAME}-not-mounted ${RESULT}" | tee -a "${RESULT_FILE}"

		if [ "${RESULT}" = "pass" ]; then
			echo "Erase device ${DEVICE}"
			if ! dd if=/dev/zero of="${DEVICE}" bs=512 count=2048; then
				RESULT=fail
			fi
		fi
		echo "block-device-${DEVNAME}-erase ${RESULT}" | tee -a "${RESULT_FILE}"

		if [ "${RESULT}" = "pass" ]; then
			echo "Create partition table on ${DEVICE}"
			echo 'type=83' | sfdisk --force "${DEVICE}" || RESULT=fail
		fi
		echo "block-device-${DEVNAME}-partition ${RESULT}" | tee -a "${RESULT_FILE}"

		if [ "${RESULT}" = "pass" ]; then
			PARTDEV="${DEVICE}1"
			echo "Format ${PARTDEV} as ext4"
			mkfs.ext4 -F "${PARTDEV}" || RESULT=fail
		fi
		echo "block-device-${PARTNAME}-format ${RESULT}" | tee -a "${RESULT_FILE}"
	else
		echo "block-device-${PARTNAME}-format skip" | tee -a "${RESULT_FILE}"
	fi
}

mount_device () {
	if [ "${RESULT}" == "pass" ] ; then
		local mounted
		mounted=$(device_mounted "${PARTDEV}")
		if [ "${mounted}" = "1" ]; then
			RESULT=skip
		else
			mkdir -p "${MOUNT_DIR}"
			mount -t auto "${PARTDEV}" "${MOUNT_DIR}" || RESULT=fail
		fi
		echo "block-device-${PARTNAME}-mount ${RESULT}" | tee -a "${RESULT_FILE}"
	fi
}

umount_device () {
	umount "${MOUNT_DIR}" || RESULT=fail
	echo "block-device-${PARTNAME}-umount ${RESULT}" | tee -a "${RESULT_FILE}"
}

copy_timing_test () {
	test_name=$1
	infile=$2
	outfile=$3

	if [ "${RESULT}" == "pass" ] ; then
		timings=$(mktemp "/tmp/block-device.timings.XXXXXXXXXXXX")
		(dd if="${infile}" of="${outfile}" 2> "${timings}" && sync) || RESULT=fail
		cat "${timings}"

		if [ "${RESULT}" == "pass" ] ; then
			local seconds
			local mbps
			seconds=$(tail -1 "${timings}" | awk '{print $8}')
			mbps=$(tail -1 "${timings}" | awk '{print $10}')
			echo "block-device-${PARTNAME}-${test_name}-timing ${RESULT} ${seconds} seconds" | tee -a "${RESULT_FILE}"
			echo "block-device-${PARTNAME}-${test_name}-throughput ${RESULT} ${mbps} MB/s" | tee -a "${RESULT_FILE}"
		fi
		rm -f "${timings}"

		echo "block-device-${PARTNAME}-${test_name}-cp ${RESULT}" | tee -a "${RESULT_FILE}"
	fi
	if [ "${RESULT}" == "pass" ] ; then
		cmp "${infile}" "${outfile}" || RESULT=fail
		echo "block-device-${PARTNAME}-${test_name}-cmp ${RESULT}" | tee -a "${RESULT_FILE}"
	fi
}

write_timing () {
	if [ "${RESULT}" == "pass" ] ; then
		echo "Writing 10MB file to ${PARTDEV}"
		dd if=/dev/urandom of="${TMPFILE}" bs=1024 count=10240 || RESULT=fail
		echo "block-device-${PARTNAME}-create-10M-file ${RESULT}" | tee -a "${RESULT_FILE}"
	fi
	if [ "${RESULT}" == "pass" ] ; then
		# shellcheck disable=SC2086
		copy_timing_test "write" "${TMPFILE}" "${MOUNT_DIR}/$(basename -- ${TMPFILE})" || RESULT=fail
	fi
	rm -f "${TMPFILE}"
}

read_timing () {
	if [ "${RESULT}" == "pass" ] ; then
		echo "Reading 10MB file to ${PARTDEV}"
		# shellcheck disable=SC2086
		copy_timing_test "read" "${MOUNT_DIR}/$(basename -- ${TMPFILE})" "${TMPFILE}" || RESULT=fail
		rm -f "${TMPFILE}"
	fi
}

bonnie_test () {
	if [ "${RESULT}" == "pass" ] ; then
		BONNIE_LOG=$(mktemp "/tmp/bonnie.XXXXX")
		bonnie\+\+ -u root -d "${MOUNT_DIR}" | tee -a "${BONNIE_LOG}" || RESULT=fail
		echo "block-device-${PARTNAME}-bonnie++ ${RESULT}" | tee -a "${RESULT_FILE}"
	fi
}

################################################################################
# Run the test actions
################################################################################
echo "Test Parameters"
echo "---------------"
echo "PARTDEV: ${PARTDEV}"
echo "PARTNAME: ${PARTNAME}"
echo "DEVICE: ${DEVICE}"
echo "RESULT_FILE: ${RESULT_FILE}"
echo ""
echo "MOUNT_DIR: ${MOUNT_DIR}"
echo "TMPFILE: ${TMPFILE}"
echo ""

install
create_out_dir "${OUTPUT}"
wait_for_device "${DEVICE}"
format_device
mount_device
write_timing
read_timing
bonnie_test
umount_device

# Cleanup temporary files
rm -f "${TMPFILE}"
rm -rf "${MOUNT_DIR}"
