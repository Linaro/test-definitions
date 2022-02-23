#!/bin/bash

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
RESULT_LOG="${OUTPUT}/result_log.txt"
TMP_LOG="${OUTPUT}/tmp_log.txt"
TEST_PASS_LOG="${OUTPUT}/test_pass_log.txt"
TEST_FAIL_LOG="${OUTPUT}/test_fail_log.txt"
TEST_SKIP_LOG="${OUTPUT}/test_skip_log.txt"
TEST_METRIC_LOG="${OUTPUT}/test_metric_log.txt"
METRIC_FILE="${OUTPUT}/metric.txt"

# set it to VDSO_INSTALL_PATH=/opt/vdsotest if you want to use git
VDSO_INSTALL_PATH=/usr
TEST_PROGRAM=vdsotest
TEST_PROG_VERSION=
TEST_GIT_URL=https://github.com/nathanlynch/vdsotest.git
TEST_DIR="$(pwd)/${TEST_PROGRAM}"
SKIP_INSTALL="false"
API=""
DURATION=""
VDSOTESTALL="yes"
TEST_TYPE=""
usage() {
	echo "\
	Usage: [sudo] ./vdso.sh [-a <API>]
				[-d <DURATION>]
				[-f <ALL>]
				[-t <TEST-TYPE>]
				[-v <TEST_PROG_VERSION>]
				[-u <TEST_GIT_URL>]
				[-p <TEST_DIR>]
				[-s <true|false>]
				[-h help]

	<API>:
	where API must be one of:
	clock-gettime-monotonic
	clock-getres-monotonic
	clock-gettime-monotonic-coarse
	clock-getres-monotonic-coarse
	clock-gettime-monotonic-raw
	clock-getres-monotonic-raw
	clock-gettime-tai
	clock-getres-tai
	clock-gettime-boottime
	clock-getres-boottime
	clock-gettime-realtime
	clock-getres-realtime
	clock-gettime-realtime-coarse
	clock-getres-realtime-coarse
	getcpu
	gettimeofday

	<DURATION>:
	Time in long will the test be running. DURATION can be set
	to X
	default: 1s - seconds

	<ALL>:
	Run all tests
	default: all

	<TEST_TYPE>:
	TEST_TYPE must be one of:
	verify
	bench
	abi

	<TEST_PROG_VERSION>:
	If this parameter is set, then the ${TEST_PROGRAM} is cloned. In
	particular, the version of the suite is set to the commit
	pointed to by the parameter. A simple choice for the value of
	the parameter is, e.g., HEAD. If, instead, the parameter is
	not set, then the suite present in TEST_DIR is used.

	<TEST_GIT_URL>:
	If this parameter is set, then the ${TEST_PROGRAM} is cloned
	from the URL in TEST_GIT_URL. Otherwise it is cloned from the
	standard repository for the suite. Note that cloning is done
	only if TEST_PROG_VERSION is not empty

	<TEST_DIR>:
	If this parameter is set, then the ${TEST_PROGRAM} suite is cloned to or
	looked for in TEST_DIR. Otherwise it is cloned to /opt/${TEST_PROGRAM}

	If next parameter is set, then the vdso suite is cloned to or
	looked for in VDSO_INSTALL_PATH. Otherwise it is cloned to /opt/vdso
	<VDSO_INSTALL_PATH>

	<SKIP_INSTALL>:
	If you already have it installed into the rootfs.
	default: false"
}

while getopts "a:d:f:i:t:hp:u:s:v:" opt; do
	case "${opt}" in
		a)
			API="${OPTARG}"
			;;
		d)
			DURATION="-d ${OPTARG}"
			;;
		f)
			VDSOTESTALL="${OPTARG}"
			;;
		i)
			VDSO_INSTALL_PATH="${OPTARG}"
			;;
		t)
			TEST_TYPE="${OPTARG}"
			;;

		u)
			if [[ "${OPTARG}" != '' ]]; then
				TEST_GIT_URL="${OPTARG}"
			fi
			;;
		p)
			if [[ "${OPTARG}" != '' ]]; then
				TEST_DIR="${OPTARG}"
			fi
			;;
		s)
			SKIP_INSTALL="${OPTARG}"
			;;
		v)
			TEST_PROG_VERSION="${OPTARG}"
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
			pkgs="git build-essential libnuma-dev python3-dev"
			install_deps "${pkgs}" "${SKIP_INSTALL}"
			;;
		fedora|centos)
			pkgs="git-core make automake gcc gcc-c++ kernel-devel numactl-devel"
			install_deps "${pkgs}" "${SKIP_INSTALL}"
			;;
		# When build do not have package manager
		# Assume dependencies pre-installed
		*)
			echo "Unsupported distro: ${dist}! Package installation skipped!"
			;;
	esac
}

install_vdso_tests() {
	pushd "${TEST_DIR}" || exit
	./autogen.sh && ./configure --prefix="${VDSO_INSTALL_PATH}" && make && make install
	popd || exit
}

parse_output() {
	# Replace special chars wit space in results file
	sed -i -e 's/(/ /g' "${RESULT_LOG}"
	sed -i -e 's/)/ /g' "${RESULT_LOG}"
	sed -i -e 's/:/ /g' "${RESULT_LOG}"
	sed -i -e 's/,/ /g' "${RESULT_LOG}"
	# Parse each type of results
	grep -E "OK" "${RESULT_LOG}" | tee -a "${TEST_PASS_LOG}"
	awk '{for (i=1; i<NF-1; i++) printf $i "-"; print $i " " "pass"}' "${TEST_PASS_LOG}" 2>&1 | tee -a "${RESULT_FILE}"

	grep -E "FAIL" "${RESULT_LOG}" | tee -a "${TEST_FAIL_LOG}"
	awk '{for (i=1; i<NF-1; i++) printf $i "-"; print $i " " "fail"}' "${TEST_FAIL_LOG}" 2>&1 | tee -a "${RESULT_FILE}"

	grep -E "SKIP" "${RESULT_LOG}" | tee -a "${TEST_SKIP_LOG}"
	awk '{for (i=1; i<NF-1; i++) printf $i "-"; print $i " " "skip"}' "${TEST_SKIP_LOG}" 2>&1 | tee -a "${RESULT_FILE}"

	grep -E "nsec/call" "${RESULT_LOG}" | tee -a "${TEST_METRIC_LOG}"
	awk '{ print $1 "-" $2 " " "pass" " " $3 " " $4 }' "${TEST_METRIC_LOG}" 2>&1 | tee -a "${METRIC_FILE}"

	# Clean up
	rm -rf "${TMP_LOG}" "${RESULT_LOG}" "${TEST_PASS_LOG}" "${TEST_FAIL_LOG}" "${TEST_SKIP_LOG}" "${TEST_METRIC_LOG}"
}

run_test() {
	if [ "${VDSOTESTALL}" = "all" ]; then
		"${VDSO_INSTALL_PATH}"/bin/vdsotest-all -g -v 2>&1 | tee -a "${RESULT_LOG}"
	else
		"${VDSO_INSTALL_PATH}"/bin/vdsotest "${DURATION}" "${API}" "${TEST_TYPE}" -g -v 2>&1 | tee -a "${RESULT_LOG}"
	fi
	parse_output
}


! check_root && error_msg "This script must be run as root"
create_out_dir "${OUTPUT}"

# Install and run test
if [ "${SKIP_INSTALL}" = "true" ] || [ "${SKIP_INSTALL}" = "True" ]; then
	info_msg "Skip installing package dependency for ${TEST_PROGRAM}"
else
	install
fi

if [ ! -d "${VDSO_INSTALL_PATH}" ]; then
	get_test_program "${TEST_GIT_URL}" "${TEST_DIR}" "${TEST_PROG_VERSION}" "${TEST_PROGRAM}"
	install_vdso_tests
	create_out_dir "${OUTPUT}"
elif [ ! -f "${VDSO_INSTALL_PATH}"/bin/vdsotest ]; then
	error_msg "Please install vdsotest"
fi

run_test
