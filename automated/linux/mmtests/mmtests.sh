#!/bin/bash

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
TEST_PROGRAM="mmtests"

usage() {
  echo "\
  Usage: $0 [-s] [-v <TEST_PROG_VERSION>] [-u <TEST_GIT_URL>] [-p <TEST_DIR>]
          [-c <MMTESTS_CONFIG_FILE>] [-r <MMTESTS_MAX_RETRIES>]
          [-i <MMTEST_ITERATIONS>] [-f] [-k] [-m]

  -v <TEST_PROG_VERSION>
    If this parameter is set, then the ${TEST_PROGRAM} suite is cloned. In
    particular, the version of the suite is set to the commit pointed to by the
    parameter. A simple choice for the value of the parameter is, e.g., HEAD.
    If, instead, the parameter is not set, then the suite present in TEST_DIR
    is used.

  -u <TEST_GIT_URL>
    If this parameter is set, then the ${TEST_PROGRAM} suite is cloned from the
    URL in TEST_GIT_URL. Otherwise it is cloned from the standard repository
    for the suite. Note that cloning is done only if TEST_PROG_VERSION is not
    empty.

  -p <TEST_DIR>
    If this parameter is set, then the ${TEST_PROGRAM} suite is cloned to or
    looked for in TEST_DIR. Otherwise it is cloned to $(pwd)/${TEST_PROGRAM}

  -s
    This flag disables benchmark installation and benchmark's
    dependencies installation.

  -c <MMTESTS_CONFIG_FILE>
    MMTests configuration file name that describes how the benchmarks should
    be configured and executed. Mandatory parameter. List of all config files
    can be found in <mmtests-root>/configs/ directory.
    For example, configs/config-db-sqlite-insert-small

  -r <MMTESTS_MAX_RETRIES>
    Maximum number of retries for the single benchmark's source file download.

  -i <MMTEST_ITERATIONS>
    The number of iterations to run the benchmark for.

  -f
    If this parameter is set, then the full archive of the benchmark logs is
    saved. Otherwise only the JSON files are saved.

  -k
    If this parameter is set, then results & system info will be collected.
    Requires python3 installed.

  -m
    Use monitors in MMTests run."
  exit 1
}

while getopts "c:p:r:su:v:i:fkm" opt; do
  case "${opt}" in
    c)
      if [[ ! "${OPTARG}" == config* ]]; then
        error_msg "Please specify correct MMTests configuration file."
        usage
      fi
      MMTESTS_CONFIG_FILE="${OPTARG}"
      ;;
    p)
      if [[ "$OPTARG" != '' ]]; then
        TEST_DIR="${OPTARG}"
      fi
      ;;
    r)
      MMTESTS_MAX_RETRIES="${OPTARG}"
      ;;
    s)
      SKIP_INSTALL=true
      ;;
    u)
      if [[ "$OPTARG" != '' ]]; then
        TEST_GIT_URL="${OPTARG}"
      fi
      ;;
    v)
      TEST_PROG_VERSION="${OPTARG}"
      ;;
    i)
      MMTEST_ITERATIONS="${OPTARG}"
      ;;
    f)
      FULL_ARCHIVE=true
      ;;
    k)
      COLLECT_RESULTS=true
      ;;
    m)
      USE_MONITORS=true
      ;;
    *)
      usage
      ;;
  esac
done

if [ -z "$MMTESTS_CONFIG_FILE" ]; then
  error_msg "Please specify MMTests configuration file."
  usage
fi

SKIP_INSTALL=${SKIP_INSTALL:-"false"}
TEST_PROG_VERSION=${TEST_PROG_VERSION:-"master"}
TEST_GIT_URL=https://github.com/gormanm/mmtests
TEST_DIR=${TEST_DIR:-"$(pwd)/${TEST_PROGRAM}"}
OUTPUT="${TEST_DIR}/output"
MMTESTS_MAX_RETRIES=${MMTESTS_MAX_RETRIES:-"3"}
MMTEST_ITERATIONS=${MMTEST_ITERATIONS:-"10"}
# Name of the directory where results will be stored by MMTests
RESULTS_DIR=$(basename "$MMTESTS_CONFIG_FILE")
COLLECTOR=$PWD/collector.py

check_perl_module() {
  # Function to check if a Perl module is installed
  cpan -l | grep -q "$1"
}

install_perl_deps() {
  # List of Perl dependencies for MMTests
  declare -a perl_modules=("JSON" "Cpanel::JSON::XS" "List::BinarySearch" "List::MoreUtils")
  # Check each module and install if necessary
  for module in "${perl_modules[@]}"; do
    if ! check_perl_module "${module}"; then
      cpan -f -i "${module}"
    else
      info_msg "perl module ${module} is already installed"
    fi
  done
  unset PERL_MM_USE_DEFAULT
}

install_system_deps() {
  # Install system-wide dependencies required for the benchmarks and MMTests framework.
  dist=
  dist_name
  case "${dist}" in
  debian|ubuntu)
    pkgs="build-essential wget perl git autoconf automake bc binutils-dev \
      btrfs-progs linux-cpupower expect gcc hdparm hwloc-nox libtool numactl \
      tcl time xfsprogs xfslibs-dev libopenmpi-dev"
    install_deps "${pkgs}" "${SKIP_INSTALL}"
    ;;
  fedora|centos)
    pkgs="git gcc make automake libtool wget perl autoconf bc binutils-devel \
      btrfs-progs kernel-tools expect hdparm hwloc libtool numactl tcl time \
      xfsprogs openmpi-devel"
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
  pushd "${TEST_DIR}" || exit 1
  AUTO_PACKAGE_INSTALL=yes
  export AUTO_PACKAGE_INSTALL
  downloaded=0
  counter=0
  # Install benchmark according to the configuration file.
  while [ $downloaded -eq 0 ] && [ $counter -lt "$MMTESTS_MAX_RETRIES" ]; do
    ./run-mmtests.sh -b -n -c "${MMTESTS_CONFIG_FILE}" "${RESULTS_DIR}" && downloaded=1
    counter=$((counter+1))
  done
  popd || exit 1
}

run_test() {
  info_msg "Running ${MMTESTS_CONFIG_FILE} test..."
  # It's required to export MMTEST_ITERATIONS as it will be used by
  # run-mmtests.sh from the MMTests package.
  export MMTEST_ITERATIONS=${MMTEST_ITERATIONS}
  # Disable packages auto installation
  touch ~/.mmtests-never-auto-package-install
  # Use nice to increase priority for the benchmark
  BASE_CMD="nice -n -5 ./run-mmtests.sh -c ${MMTESTS_CONFIG_FILE} ${RESULTS_DIR}"
  if [ "${USE_MONITORS}" = "true" ]; then
    BASE_CMD="${BASE_CMD} -m"
    info_msg "Monitors are ON in MMTests run"
  else
    BASE_CMD="${BASE_CMD} -n"
    info_msg "Monitors are OFF in MMTests run"
  fi
  eval "${BASE_CMD}"
}

collect_results() {
  command="python3 $COLLECTOR -c $MMTESTS_CONFIG_FILE -d $TEST_DIR -i $MMTEST_ITERATIONS -o $OUTPUT"

  if [ ! -f "$FULL_ARCHIVE" ]; then
    eval "$command" -f
  else
    eval "$command"
  fi
}

! check_root && error_msg "Please run this script as root."

if [ "${SKIP_INSTALL}" = "true" ]; then
  info_msg "Installation skipped"
else
  # Install system-wide dependencies.
  install_system_deps
  # Install perl dependencies.
  install_perl_deps
  # Clone MMTests repository.
  get_test_program "${TEST_GIT_URL}" "${TEST_DIR}" "${TEST_PROG_VERSION}" "${TEST_PROGRAM}"
  # Due to logic of get_test_program function, its needed to get back
  cd - || exit 1
  # Install benchmark and Perl dependencies.
  prepare_system
fi

create_out_dir "${OUTPUT}"
pushd "${TEST_DIR}" || exit 1
run_test

if [ "${COLLECT_RESULTS}" = "true" ]; then
  collect_results
else
  info_msg "Results can be found in ${TEST_DIR}/work/log/${RESULTS_DIR}"
fi
