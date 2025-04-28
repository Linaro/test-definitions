#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2024 Linaro Ltd.

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE

MODULES_LIST=""
MODULES_SUBDIRS=""
MODULE_MODPROBE_NUMBER="1"
SKIPLIST=""
SHARD_NUMBER=1
SHARD_INDEX=1

usage() {
	echo "Usage: $0 [-d <subdir of the modules directory> ]
		[-l <space separated module list> ]
		[-c <Number of load/unload of a module> ]
		[-i <sharding bucket to run> ]
		[-n <number of shard buckets to create> ]
		[-s <skiplist modules to skip> ]
		[-h ]" 1>&2
	exit 0
}

while getopts "c:d:i:l:n:s:h" o; do
	case "$o" in
		d) MODULES_SUBDIRS="${OPTARG}" ;;
		l) MODULES_LIST="${OPTARG}" ;;
		c) MODULE_MODPROBE_NUMBER="${OPTARG}" ;;
		i) SHARD_INDEX="${OPTARG}" ;;
		n) SHARD_NUMBER="${OPTARG}" ;;
		s) SKIPLIST="${OPTARG}" ;;
		h|*) usage ;;
	esac
done

get_modules_list() {
	if [ -z "${MODULES_LIST}" ]; then
		subdir=$(echo "${MODULES_SUBDIRS}" | tr ' ' '|')
		skiplist=$(echo "${SKIPLIST}" | tr ' ' '|')
		grep -E "kernel/(${subdir})" /lib/modules/"$(uname -r)"/modules.order | tee /tmp/find_modules.txt
		grep -E -v "(${skiplist})" /tmp/find_modules.txt | tee /tmp/modules_to_run.txt
		split --verbose --numeric-suffixes=1 -n l/"${SHARD_INDEX}"/"${SHARD_NUMBER}" /tmp/modules_to_run.txt > /tmp/shardfile
		echo "============== Tests to run ==============="
		cat /tmp/shardfile
		echo "===========End Tests to run ==============="
		if [ -s /tmp/shardfile ]; then
			report_pass "shardfile"
		else
			report_fail "shardfile"
		fi
		while IFS= read -r line
		do
			module_basename=$(basename "${line}")
			module_name=${module_basename%.*}
			MODULES_LIST="${MODULES_LIST} ${module_name}"
		done < /tmp/shardfile
	fi
}

report() {
	local _modprop_flag="${1}"
	local _module="${2}"
	local _text="${3}"
	local _num="${4}"
	echo
	echo "${_text} module: ${_module}"
	if ! modprobe "${_module}" "${_modprop_flag}"; then
		report_fail "${_text}_module_${_num}_${_module}"
	else
		report_pass "${_text}_module_${_num}_${_module}"
	fi
}

scan_dmesg_for_errors() {
	echo "=== Scanning dmesg for errors ==="
	dmesg -l 0,1,2,3,4,5 | grep -Ei "BUG:|WARNING:|Oops:|Call Trace:" && report_fail "dmesg_error_scan" || report_pass "dmesg_error_scan"
}

check_module_unloaded() {
	local _module="$1"
	if lsmod | grep "^${_module} " > /dev/null; then
		echo "Module ${_module} still loaded after removal!"
		report_fail "module_stuck_${_module}"
	else
		report_pass "module_unloaded_${_module}"
	fi
}

run () {
	for module in ${MODULES_LIST}; do
		# don't insert/remove modules that is already inserted.
		if ! lsmod | grep "^${module}"; then
			for num in $(seq "${MODULE_MODPROBE_NUMBER}"); do
				dmesg -C
				report "" "${module}" "insert" "${num}"
				echo
				echo "modinfo ${module}"
				modinfo "${module}"
				scan_dmesg_for_errors

				report "--remove" "${module}" "remove" "${num}"
				scan_dmesg_for_errors

				check_module_unloaded "${module}"
			done
		fi
	done
}

# Test run.
! check_root && error_msg "This script must be run as root"
create_out_dir "${OUTPUT}"
info_msg "Output directory: ${OUTPUT}"
info_msg "About to run  load/unload kernel modules ..."
get_modules_list
run
