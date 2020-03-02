#!/bin/sh
# shellcheck disable=SC1091

OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"

. ../../lib/sh-test-lib

create_out_dir "${OUTPUT}"

usage() {
    echo "Usage: $0 [-e <extra files>]" 1>&2
    exit 1
}

while getopts "e:h:s" o; do
  case "$o" in
    e) EXTRA_FILES="${OPTARG}" ;;
    h|*) usage ;;
  esac
done

###############
# Generic files
###############
filelist=" \
	/dev/urandom \
	/dev/null \
	/dev/zero \
"

file_exists()
{
	file=$1
	if [ -e "${file}" ]; then
		result="PASS"
	else
		result="FAIL"
	fi
	echo "file_exists_$file ${result}" | sed 'sX/X_Xg' | tee -a "${RESULT_FILE}"
}

check_file_list()
{
	filelist="$*"
	for file in ${filelist}; do
		file_exists "$file"
	done
}

add_to_list()
{
	file="${1}".lst

	if [ -e "${file}" ]; then
		newfilelist=$(cat "${file}")
		filelist="${filelist} ${newfilelist}"
	fi
}

files_exist()
{
	kernel_version="$(uname -a | awk '{print $3}' | awk -F. '{print $1"."$2}')"
	model="unknown"
	model_file=/proc/device-tree/model

	if [ -e "${model_file}" ]; then
		model=$(tr -d '\0' </proc/device-tree/model)
	fi
	case "${model}" in
	*"RZ/N1D"*)
		machine=lces2
		;;
	*"SOCA9"*)
		machine=soca9
		;;
	*)
		machine=unknown
		;;
	esac

	add_to_list "${machine}"
	add_to_list "${machine}-${kernel_version}"
	filelist="${filelist} ${EXTRA_FILES}"
	check_file_list "${filelist}"
}

files_exist
