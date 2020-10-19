#!/bin/bash

set -x

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
RESULT_LOG="${OUTPUT}/result_log.txt"
TMP_LOG="${OUTPUT}/tmp_log.txt"
TEST_PASS_LOG="${OUTPUT}/test_pass_log.txt"
TEST_FAIL_LOG="${OUTPUT}/test_fail_log.txt"
TEST_SKIP_LOG="${OUTPUT}/test_skip_log.txt"
export RESULT_FILE

TESTS="oops --uefitests"
FWTS_VERSION=
FWTS_URL=https://github.com/ColinIanKing/fwts.git
FWTS_PATH="/bin"
SKIP_INSTALL="false"

usage() {
	echo "\
	Usage: [sudo] ./fwts.sh [-t <TESTS>]
				     [-v <FWTS_VERSION>] [-u <FWTS_URL>] [-p <FWTS_PATH>]
				     [-s <true|false>]

	<TESTS>:
	Set of tests: 'throughput' benchmarks throughput, while
	'replayed-startup' benchmarks the start-up times of popular
	applications, by replaying their I/O. The replaying saves us
	from meeting all non-trivial dependencies of these applications
	(such as having an X session running). Results are
	indistinguishable w.r.t. to actually starting these applications.
	Default value: \"throughput replayed-startup\"

	<FWTS_VERSION>:
	If this parameter is set, then the FWTS suite is cloned. In
	particular, the version of the suite is set to the commit
	pointed to by the parameter. A simple choice for the value of
	the parameter is, e.g., HEAD. If, instead, the parameter is
	not set, then the suite present in FWTS_PATH is used.

	<FWTS_URL>:
	If this parameter is set, then the FWTS suite is cloned
	from the URL in FWTS_URL. Otherwise it is cloned from the
	standard repository for the suite. Note that cloning is done
	only if FWTS_VERSION is not empty

	<FWTS_PATH>:
	If this parameter is set, then the FWTS suite is cloned to or
	looked for in FWTS_PATH. Otherwise it is cloned to $(pwd)/fwts

	<SKIP_INSTALL>:
	If you already have it installed into the rootfs.
	default: false"
}

while getopts "h:t:p:u:v:s:" opt; do
	case $opt in
		t)
			TESTS="$OPTARG"
			;;
		v)
			FWTS_VERSION="$OPTARG"
			;;
		u)
			if [[ "$OPTARG" != '' ]]; then
				FWTS_URL="$OPTARG"
			fi
			;;
		p)
			if [[ "$OPTARG" != '' ]]; then
				FWTS_PATH="$OPTARG"
			fi
			;;
		s)
			SKIP_INSTALL="${OPTARG}"
			;;
		h)
			usage
			exit 0
			;;
		*)
			usage
			exit 1
			;;
	esac
done

install() {
	dist=
	dist_name
	case "${dist}" in
		debian|ubuntu)
			pkgs="fio sysstat libaio-dev gawk coreutils bc \
				  psmisc g++ git"
			install_deps "${pkgs}" "${SKIP_INSTALL}"
			;;
		fedora|centos)
			pkgs="fio sysstat libaio-devel gawk coreutils bc \
				  psmisc gcc-c++ git-core"
			install_deps "${pkgs}" "${SKIP_INSTALL}"
			;;
		# When build do not have package manager
		# Assume dependencies pre-installed
		*)
			echo "Unsupported distro: ${dist}! Package installation skipped!"
			;;
	esac
}

get_tests() {
	if [[ "$FWTS_VERSION" != "" && ( ! -d "$FWTS_PATH" || -d "$FWTS_PATH"/.git ) ]];
	then
		if [[ -d "$FWTS_PATH"/.git ]]; then
			echo Using repository "$PATH"
		else
			git clone "$FWTS_URL" "$FWTS_PATH"
		fi

		cd "$FWTS_PATH" || exit 1
		if [[ "$FWTS_VERSION" != "" ]]; then
			if ! git reset --hard "$FWTS_VERSION"; then
				echo Failed to set FWTS to commit "$FWTS_VERSION", sorry
				exit 1
			fi
		else
			echo Using "$PATH"
		fi

	else
		if [[ ! -d "$FWTS_PATH" ]]; then
			echo No FWTS suite in "$FWTS_PATH", sorry
			exit 1
		fi
		echo Assuming FWTS is pre-installed in "$FWTS_PATH"
		cd "$FWTS_PATH" || exit 1
	fi
}

# Parse fwts test results
parse_fwts_test_results() {
	grep -a -E "PASSED" "${RESULT_LOG}" | tee -a "${TEST_PASS_LOG}"
	sed -i -e 's/(//g' "${TEST_PASS_LOG}"
	sed -i -e 's/)//g' "${TEST_PASS_LOG}"
	sed -i -e 's/://g' "${TEST_PASS_LOG}"
	sed -i -e 's/,//g' "${TEST_PASS_LOG}"
	sed -i -e 's/\\//g' "${TEST_PASS_LOG}"
	awk '{for (i=2; i<NF; i++) printf $i "-"; print $i " " $1}' "${TEST_PASS_LOG}" 2>&1 | tee -a "${RESULT_FILE}"
	sed -i -e 's/PASSED/pass/g' "${RESULT_FILE}"

	grep -a -E "Failed" "${RESULT_LOG}" | tee -a "${TEST_FAIL_LOG}"
	sed -i -e 's/\[[0-9]*m//g' "${TEST_FAIL_LOG}"
	sed -i -e 's/(//g' "${TEST_FAIL_LOG}"
	sed -i -e 's/)//g' "${TEST_FAIL_LOG}"
	sed -i -e 's/://g' "${TEST_FAIL_LOG}"
	sed -i -e 's/,//g' "${TEST_FAIL_LOG}"
	sed -i -e 's/\\//g' "${TEST_FAIL_LOG}"
	awk '{for (i=2; i<NF; i++) printf $i "-"; print $i " " $1}' "${TEST_FAIL_LOG}" 2>&1 | tee -a "${RESULT_FILE}"
	sed -i -e 's/Failed/fail/g' "${RESULT_FILE}"

	grep -a -E "SKIPPED" "${RESULT_LOG}" | tee -a "${TEST_SKIP_LOG}"
	sed -i -e 's/\[[0-9]*m//g' "${TEST_SKIP_LOG}"
	sed -i -e 's/(//g' "${TEST_SKIP_LOG}"
	sed -i -e 's/)//g' "${TEST_SKIP_LOG}"
	sed -i -e 's/://g' "${TEST_SKIP_LOG}"
	sed -i -e 's/,//g' "${TEST_SKIP_LOG}"
	sed -i -e 's/\\//g' "${TEST_SKIP_LOG}"
	awk '{for (i=2; i<NF; i++) printf $i "-"; print $i " " $1}' "${TEST_SKIP_LOG}" 2>&1 | tee -a "${RESULT_FILE}"
	sed -i -e 's/SKIPPED/skip/g' "${RESULT_FILE}"

	# Clean up
	rm -rf "${TMP_LOG}" "${RESULT_LOG}" "${TEST_PASS_LOG}" "${TEST_FAIL_LOG}" "${TEST_SKIP_LOG}"
}

run_test() {

        # shellcheck disable=SC2086
	fwts ${TESTS} - 2>&1 | tee -a "${RESULT_LOG}"
	parse_fwts_test_results
}

! check_root && error_msg "This script must be run as root"
create_out_dir "${OUTPUT}"

# Install and run test

if [ "${SKIP_INSTALL}" = "true" ] || [ "${SKIP_INSTALL}" = "True" ]; then
	info_msg "fwts installation skipped altogether"
else
	install
fi

which fwts
if [ $? -eq 1 ]; then
	get_tests
fi
run_test "${TESTS}"
