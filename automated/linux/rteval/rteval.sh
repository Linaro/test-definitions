#!/bin/bash

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"

DOWNLOAD_KERNEL="https://mirrors.edge.kernel.org/pub/linux/kernel/v5.x/linux-5.7.tar.xz"
TEST_PROGRAM=rteval
TEST_PROG_VERSION=
TEST_GIT_URL=https://kernel.googlesource.com/pub/scm/utils/rteval/rteval.git
TEST_DIR="/opt/${TEST_PROGRAM}"
SKIP_INSTALL="false"
DURATION="10m"

usage() {
	echo "\
	Usage: [sudo] ./rteval.sh [-d <DURATION>] [-v <TEST_PROG_VERSION>]
				  [-u <TEST_GIT_URL>] [-p <TEST_DIR>] [-s <true|false>]

	<DURATION>:
	Time in long will the test be running. DURATION can be set
	to Xs, Xm, Xh, Xd.
	s - seconds,
	m - minutes,
	h - hours,
	d - days
	default: 10m

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

	<SKIP_INSTALL>:
	If you already have it installed into the rootfs.
	default: false"
}

while getopts "d:hk:p:u:s:v:" opt; do
	case $opt in
		d)
			DURATION="$OPTARG"
			;;
		k)
			DOWNLOAD_KERNEL="$OPTARG"
			;;
		u)
			if [[ "$OPTARG" != '' ]]; then
				TEST_GIT_URL="$OPTARG"
			fi
			;;
		p)
			if [[ "$OPTARG" != '' ]]; then
				TEST_DIR="$OPTARG"
			fi
			;;
		s)
			SKIP_INSTALL="${OPTARG}"
			;;
		v)
			TEST_PROG_VERSION="$OPTARG"
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
			pkgs="curl git python3-dev python3-schedutils python3-ethtool python3-lxml python3-dmidecode rt-tests sysstat xz-utils bzip2 tar numactl build-essential flex bison bc elfutils openssl libssl-dev cpio libelf-dev binutils linux-libc-dev keyutils libaio-dev attr libpcap-dev lksctp-tools zlib1g-dev util-linux"
			install_deps "${pkgs}" "${SKIP_INSTALL}"
			;;
		fedora|centos)
			pkgs="curl git-core python3-devel python3-schedutils python3-ethtool python3-lxml python3-dmidecode sysstat numactl gcc flex bison bc make elfutils elfutils-libelf-devel openssl-devel libaio-devel libattr-devel libcap-devel lksctp-tools-devel zlib-devel"
			install_deps "${pkgs}" "${SKIP_INSTALL}"
			;;
		# When build do not have package manager
		# Assume dependencies pre-installed
		*)
			echo "Unsupported distro: ${dist}! Package installation skipped!"
			;;
	esac
	openssl req -new -nodes -utf8 -sha256 -days 36500 -batch -x509 -config x509.genkey -outform PEM -out kernel_key.pem -keyout kernel_key.pem

}

install_rt_tests() {
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
	git clone https://git.kernel.org/pub/scm/utils/rt-tests/rt-tests.git
	pushd rt-tests || exit
	git checkout v1.8
	make && make install
	popd || exit
	rm -rf rt-tests
}

run_test() {

	ln -s /bin/dmesg /usr/bin/dmesg
	pushd "$TEST_DIR" || exit 1
	pushd loadsource || exit 1
	curl -sSOL "${DOWNLOAD_KERNEL}"
	popd || exit
	sed -ie "s|linux-.*|$(basename "${DOWNLOAD_KERNEL}")|" Makefile
	make install
	echo D="${DURATION}"
	#sed -ie "s|^verbose: .*|verbose: True|g" rteval.conf
	sed -ie "s|^duration: .*|duration: ${DURATION}|g" rteval.conf
	echo "dbench: external">>rteval.conf
	date

	cat rteval.conf

	date
	make runit D="${DURATION}" 2>&1 | tee "${RESULT_FILE}"
	date
	popd || exit
}

! check_root && error_msg "This script must be run as root"

# Install and run test

if ! command -v cyclictest > /dev/null; then
	install_rt_tests
fi

if [ "${SKIP_INSTALL}" = "true" ] || [ "${SKIP_INSTALL}" = "True" ]; then
	info_msg "Skip installing package dependency for ${TEST_PROG_VERSION}"
else
	install
fi

get_test_program "${TEST_GIT_URL}" "${TEST_DIR}" "${TEST_PROG_VERSION}" "${TEST_PROGRAM}"
create_out_dir "${OUTPUT}"
run_test
