#!/bin/bash
# Sysbench is a modular, cross-platform and multi-threaded benchmark tool.
# This runs the CPU microbench which calculates primes up to a
# certain value using varying numbers of instances.
# In this configuration, it calculates primes up to 25000
# using between 1 and 2*NUMCPUS threads.

# shellcheck disable=SC1091
. ../../lib/sh-test-lib

OUTPUT="$(pwd)/output"
TEST_PROGRAM="mmtests"
TEST_PROG_VERSION=
TEST_GIT_URL=https://github.com/gormanm/mmtests
TEST_DIR="$(pwd)/${TEST_PROGRAM}"
SKIP_INSTALL="false"
MMTESTS_MAX_RETRIES=10
MMTESTS_TYPE_NAME=
MMTESTS_CONFIG_FILE=

declare -A altreport_mappings=( ["dbench4"]="tput latency opslatency")
declare -A env_variable_mappings=( ["dbench4"]="DBENCH" )

usage() {
	echo "\
	Usage: $0 [-s <true|false>] [-v <TEST_PROG_VERSION>]
			[-u <TEST_GIT_URL>] [-p <TEST_DIR>]
			[-c <MMTESTS_CONFIG_FILE>] [-t <MMTESTS_TYPE_NAME>] [-r <MMTESTS_MAX_RETRIES>]

	<TEST_PROG_VERSION>:
	If this parameter is set, then the ${TEST_PROGRAM} suite is cloned. In
	particular, the version of the suite is set to the commit
	pointed to by the parameter. A simple choice for the value of
	the parameter is, e.g., HEAD. If, instead, the parameter is
	not set, then the suite present in TEST_DIR is used.

	<TEST_GIT_URL>:
	If this parameter is set, then the ${TEST_PROGRAM} suite is cloned
	from the URL in TEST_GIT_URL. Otherwise it is cloned from the
	standard repository for the suite. Note that cloning is done
	only if TEST_PROG_VERSION is not empty

	<TEST_DIR>:
	If this parameter is set, then the ${TEST_PROGRAM} suite is cloned to or
	looked for in TEST_DIR. Otherwise it is cloned to $(pwd)/${TEST_PROGRAM}

	<SKIP_INSTALL>:
	If you already have it installed into the rootfs.
	default: false

	<MMTESTS_CONFIG_FILE>:
	Mmtests configuration file that describes how the benchmarks should be
	configured and executed.

	<MMTESTS_TYPE_NAME>:
	Mtests test type, e.g. sysbenchcpu, iozone, sqlite, etc.

	<MMTESTS_MAX_RETRIES>:
	Maximum number of retries for the single benchamrk's source file download"
	exit 1
}

while getopts "c:p:r:s:t:u:v:" opt; do
	case "${opt}" in
		c)
			MMTESTS_CONFIG_FILE="${OPTARG}"
			;;
		p)
			if [[ "$OPTARG" != '' ]]; then
				TEST_DIR="$OPTARG"
			fi
			;;
		r)
			MMTESTS_MAX_RETRIES="${OPTARG}"
			;;
		s)
			SKIP_INSTALL="${OPTARG}"
			;;
		t)
			MMTESTS_TYPE_NAME="${OPTARG}"
			;;
		u)
			if [[ "$OPTARG" != '' ]]; then
				TEST_GIT_URL="$OPTARG"
			fi
			;;
		v)
			TEST_PROG_VERSION="$OPTARG"
			;;
		*)
			usage
			;;
	esac
done

install() {
	dist=
	dist_name
	case "${dist}" in
	debian|ubuntu)
			pkgs="build-essential wget perl git autoconf automake \
					bc binutils-dev btrfs-progs linux-cpupower expect \
					gcc hdparm hwloc-nox libtool numactl tcl time \
					xfsprogs xfslibs-dev libopenmpi-dev jq"
			install_deps "${pkgs}" "${SKIP_INSTALL}"
		;;
	fedora|centos)
		pkgs="git gcc make automake libtool wget perl autoconf \
					bc binutils-devel btrfs-progs kernel-tools expect \
					hdparm hwloc libtool numactl tcl time xfsprogs \
					openmpi-devel"
			install_deps "${pkgs}" "${SKIP_INSTALL}"
		;;
	oe-rpb)
		# Assume all dependent packages are already installed.
		;;
	*)
		warn_msg "Unsupported distro: ${dist}! Package installation skipped!"
		;;
	esac
}

prepare_system() {
	pushd "${TEST_DIR}" || exit
	PERL_MM_USE_DEFAULT=1
	export PERL_MM_USE_DEFAULT
	cpan -f -i JSON Cpanel::JSON::XS List::BinarySearch
	AUTO_PACKAGE_INSTALL=yes
	export AUTO_PACKAGE_INSTALL
	DOWNLOADED=0
	COUNTER=0
	while [ $DOWNLOADED -eq 0 ] && [ $COUNTER -lt "$MMTESTS_MAX_RETRIES" ]; do
		./run-mmtests.sh -b --no-monitor --config "${MMTESTS_CONFIG_FILE}" benchmark && DOWNLOADED=1
		COUNTER=$((COUNTER+1))
	done
	popd || exit
}

run_test() {
	pushd "${TEST_DIR}" || exit
	info_msg "Running ${MMTESTS_TYPE_NAME} test..."
	extracted_json="../${MMTESTS_TYPE_NAME}.json"
	./run-mmtests.sh --no-monitor --config "${MMTESTS_CONFIG_FILE}" benchmark
	./bin/extract-mmtests.pl -d work/log/ -b "${MMTESTS_TYPE_NAME}" -n benchmark --print-json > "$extracted_json"
	altreports=${altreport_mappings[${MMTESTS_TYPE_NAME}]}
	for altreport in ${altreports}; do
		./bin/extract-mmtests.pl -d work/log/ -b "${MMTESTS_TYPE_NAME}" -n benchmark\
		-a "${altreport}" --print-json > "../${MMTESTS_TYPE_NAME}_${altreport}.json"
	done

	MEMTOTAL_BYTES=$(free -b | grep Mem: | awk '{print $2}')
	export MEMTOTAL_BYTES
	NUMCPUS=$(grep -c '^processor' /proc/cpuinfo)
	export NUMCPUS
	NUMNODES=$(grep ^Node /proc/zoneinfo | awk '{print $2}' | sort | uniq | wc -l)
	export NUMNODES
	LLC_INDEX=$(find /sys/devices/system/cpu/ -type d -name "index*" | sed -e 's/.*index//' | sort -n | tail -1)
	export LLC_INDEX
	NUMLLCS=$(grep . /sys/devices/system/cpu/cpu*/cache/index"$LLC_INDEX"/shared_cpu_map | awk -F : '{print $NF}' | sort | uniq | wc -l)
	export NUMLLCS

	chmod u+x ./"${MMTESTS_CONFIG_FILE}"
	eval 'source ./${MMTESTS_CONFIG_FILE}'

	env_variables_prefix=${env_variable_mappings[${MMTESTS_TYPE_NAME}]}
	if [ -z "$env_variables_prefix" ]; then
		env_variables_prefix=${MMTESTS_TYPE_NAME^^}
	fi
	
	vars=""
	eval 'vars=${!'"$env_variables_prefix"'*}'
	for variable in ${vars}; do
		mykey=CONFIG_${variable}
		mykey=${mykey//_/-}
		myvalue=${!variable}
		echo "$mykey":"$myvalue"
		tmp=$(mktemp)
		jq --arg key "$mykey" --arg value "$myvalue" '. += {($key):$value}' ../"${MMTESTS_TYPE_NAME}".json > "$tmp" && mv "$tmp" ../"${MMTESTS_TYPE_NAME}".json
	done

	chmod a+r ../"${MMTESTS_TYPE_NAME}".json

	popd || exit
}

! check_root && error_msg "Please run this script as root."

# Test installation.
if [ "${SKIP_INSTALL}" = "true" ] || [ "${SKIP_INSTALL}" = "True" ]; then
	info_msg "${MMTESTS_TYPE_NAME} installation skipped"
else
	install
fi

get_test_program "${TEST_GIT_URL}" "${TEST_DIR}" "${TEST_PROG_VERSION}" "${TEST_PROGRAM}"

create_out_dir "${OUTPUT}"
prepare_system
run_test
