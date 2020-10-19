#!/bin/bash

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"

TESTS="throughput replayed-gnome-term-startup"
TEST_DEV=sda
FORMAT=no
S_VERSION=
S_URL=https://github.com/Algodev-github/S
S_PATH="$(pwd)/S"
SKIP_INSTALL="false"
ONLY_READS=""
NUM_REPETITIONS=5

usage() {
	echo "\
	Usage: [sudo] ./run-bench.sh [-t <TESTS>] [-d <TEST_DEV>] [-f <FORMAT>]
				     [-v <S_VERSION>] [-u <S_URL>] [-p <S_PATH>]
				     [-r <ONLY_READS>] [-s <true|false>]
				     [-n NUM_REPETITIONS]

	<TESTS>:
	Set of tests: 'throughput' benchmarks throughput, while
	'replayed-startup' benchmarks the start-up times of popular
	applications, by replaying their I/O. The replaying saves us
	from meeting all non-trivial dependencies of these applications
	(such as having an X session running). Results are
	indistinguishable w.r.t. to actually starting these applications.
	A special case for replayed-startup is replayed-gnome-term-startup:
	it benchmarks the startup of only gnome-terminal (a medium-size
	application).
	Default value: \"throughput replayed-gnome-term-startup\"

	<TEST_DEV>:
	Target device/partition: device/partition on which to
	execute the benchmarks. If a partition is specified, then
	the partition must contain a mounted filesystem. If a device
	(actual drive) is specified, then that drive must contain a
	partition ${TEST_DEV}1 in it, with a mounted fs in that
	partition. In both cases, test files are created in that
	filesystem.
	Default value: sda

	<FORMAT>:
	If this parameter is set to yes and TEST_DEV points to an actual
	drive, but the drive does not contain a mounted partition, then
	the drive is formatted, a partition with an ext4 fs is created on
	the drive, and that fs is used for the test.
	Default value: no

	<S_VERSION>:
	If this parameter is set, then the S suite is cloned. In
	particular, the version of the suite is set to the commit
	pointed to by the parameter. A simple choice for the value of
	the parameter is, e.g., HEAD. If, instead, the parameter is
	not set, then the suite present in S_PATH is used.

	<S_URL>:
	If this parameter is set, then the S suite is cloned
	from the URL in S_URL. Otherwise it is cloned from the
	standard repository for the suite. Note that cloning is done
	only if S_VERSION is not empty

	<S_PATH>:
	If this parameter is set, then the S suite is cloned to or
	looked for in S_PATH. Otherwise it is cloned to $(pwd)/S

	<ONLY_READS>:
	If this parameter is set to yes then only workloads made of
	only reads are generated in every benchmark.
	Default value: no

	<NUM_REPETITIONS>:
	Number of times each benchmark is repeated. Default: 5.

	<SKIP_INSTALL>:
	If you already have it installed into the rootfs.
	default: false"
}

while getopts "ht:d:f:p:u:v:s:r:n:" opt; do
	case $opt in
		t)
			TESTS="$OPTARG"
			;;
		d)
			TEST_DEV="$OPTARG"
			;;
		f)
			FORMAT="$OPTARG"
			;;
		v)
			S_VERSION="$OPTARG"
			;;
		u)
			if [[ "$OPTARG" != '' ]]; then
				S_URL="$OPTARG"
			fi
			;;
		p)
			if [[ "$OPTARG" != '' ]]; then
				S_PATH="$OPTARG"
			fi
			;;
		s)
			SKIP_INSTALL="${OPTARG}"
			;;
		r)
			if [[ "${OPTARG}" == yes ]]; then
				ONLY_READS="only-reads"
			fi
			;;
		n)
			NUM_REPETITIONS="$OPTARG"
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

get_ssuite() {
	if [[ "$S_VERSION" != "" && ( ! -d "$S_PATH" || -d "$S_PATH"/.git ) ]];
	then
		if [[ -d "$S_PATH"/.git ]]; then
			echo Using repository "$PATH"
		else
			git clone "$S_URL" "$S_PATH"
		fi

		cd "$S_PATH" || exit 1
		if [[ "$S_VERSION" != "" ]]; then
			if ! git reset --hard "$S_VERSION"; then
				echo Failed to set S to commit "$S_VERSION", sorry
				exit 1
			fi
		else
			echo Using "$PATH"
		fi

	else
		if [[ ! -d "$S_PATH" ]]; then
			echo No S suite in "$S_PATH", sorry
			exit 1
		fi
		echo Assuming S is pre-installed in "$S_PATH"
		cd "$S_PATH" || exit 1
	fi
}

run_test() {
	sed -i "s<TEST_DEV=.*<TEST_DEV=$2<" def_config.sh
	sed -i "s/FORMAT=.*/FORMAT=$3/" def_config.sh

	if [ "$SUDO_USER" != "" ]; then
		eval HOME_DIR=~"$SUDO_USER"
	else
		HOME_DIR=~
	fi

	rm -f ${HOME_DIR}/.S-config.sh

	cd "$S_PATH"/run_multiple_benchmarks/ || exit 1
	./run_main_benchmarks.sh "$1" "" "" "" "${ONLY_READS}" "" \
				 "${NUM_REPETITIONS}" "${OUTPUT}" 2>&1 |\
	    tee -a "${OUTPUT}/log"

	# For each benchmark, statistics (min, max, avg, std dev) on
	# the measured quantity are appended to the source result file
	# (${OUTPUT}"/result_list.txt). Here is the format of possible
	# lines in this file.
	#
	# throughput-<scheduler1_name>--<workload_name> pass <min> <max> <avg> <std dev> MB/s
	# throughput--<workload1_name>--<scheduler1_name> fail
	#
	# <app_name>-startup--<workload_name>--<scheduler1_name> pass <min> <max> <avg> <std dev> sec
	# <app_name>-startup--<workload_name>--<scheduler1_name> fail

	# LAVA does not comply with a result file in the above
	# form. To get a compliant file, we pick each statistic and
	# put it in a separate line in the destination result file
	# (${RESULT_FILE}, which is then parsed by LAVA).
	awk '{ print $1 "-min"" " $2 " " $3 " " $7 }' "${OUTPUT}"/result_list.txt 2>&1 | tee -a  "${RESULT_FILE}"
	awk '{ print $1 "-max"" " $2 " " $4 " " $7 }' "${OUTPUT}"/result_list.txt 2>&1 | tee -a  "${RESULT_FILE}"
	awk '{ print $1 "-avg"" " $2 " " $5 " " $7 }' "${OUTPUT}"/result_list.txt 2>&1 | tee -a  "${RESULT_FILE}"
	awk '{ print $1 "-std"" " $2 " " $6 " " $7 }' "${OUTPUT}"/result_list.txt 2>&1 | tee -a  "${RESULT_FILE}"
}

! check_root && error_msg "This script must be run as root"

# Install and run test

if [ "${SKIP_INSTALL}" = "true" ] || [ "${SKIP_INSTALL}" = "True" ]; then
	info_msg "ssuite installation skipped altogether"
else
	install
fi
get_ssuite
create_out_dir "${OUTPUT}"
run_test "$TESTS" "$TEST_DEV" "$FORMAT"
