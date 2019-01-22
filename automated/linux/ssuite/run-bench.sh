#!/bin/bash

. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE

TESTS="throughput replayed-startup"
TEST_DEV=sda
FORMAT=no
S_VERSION=
S_URL=https://github.com/Algodev-github/S
S_PATH="$(pwd)/S"

usage() {
	echo "\
	Usage: [sudo] ./run-bench.sh [-t <TESTS>] [-d <TEST_DEV>] [-f <FORMAT>]
				     [-v <S_VERSION>] [-u <S_URL>] [-p <S_PATH>]

	<TESTS>:
	Set of tests: 'throughput' benchmarks throughput, while
	'replayed-startup' benchmarks the start-up times of popular
	applications, by replaying their I/O. The replaying saves us
	from meeting all non-trivial dependencies of these applications
	(such as having an X session running). Results are
	indistinguishable w.r.t. to actually starting these applications.
	Default value: \"throughput replayed-startup\"

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
	If this parameter is set, then the S suite is cloned or
	looked for in S_PATH. Otherwise it is cloned to $(pwd)/S"

	exit 1
}

while getopts "ht:d:f:p:u:v:" opt; do
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
			S_URL="$OPTARG"
			;;
		p)
			S_PATH="$OPTARG"
			;;
		h)
			usage
			exit 0
			;;
	esac
done
install() {
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
			;;
	esac
}

run_test() {
	if [[ "$S_VERSION" != "" && ( ! -d $S_PATH || -d $S_PATH/.git ) ]]; then
		if [[ -d $S_PATH/.git ]]; then
			echo Using repository $PATH
		else
			git clone $S_URL $S_PATH
		fi

		cd $S_PATH
		if [[ $S_VERSION != "" ]]; then
			git reset --hard $S_VERSION
			if [[ $? -ne 0 ]]; then
				echo Failed to set S to commit $S_VERSION, sorry
				exit 1
			fi
		else
			echo Using $PATH
		fi

	else
		if [[ ! -d $S_PATH ]]; then
			exit
		fi
		echo Assuming S is pre-installed in $S_PATH
		cd $S_PATH
	fi

	sed -i "s/TEST_DEV=.*/TEST_DEV=$2/" def_config.sh
	sed -i "s/FORMAT=.*/FORMAT=$3/" def_config.sh

	if [ "$SUDO_USER" != "" ]; then
		eval HOME_DIR=~$SUDO_USER
	else
		HOME_DIR=~
	fi

	rm -f ${HOME_DIR}/.S-config.sh

	cd run_multiple_benchmarks/
	./run_main_benchmarks.sh "$1" 2>&1 | tee -a "${RESULT_FILE}"
}

if [ "$1" = -h ]; then
	usage
fi

! check_root && error_msg "This script must be run as root"

# Install and run test
install
create_out_dir "${OUTPUT}"
run_test "$TESTS" "$TEST_DEV" "$FORMAT"
