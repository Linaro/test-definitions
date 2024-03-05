#!/bin/sh
# Linux kernel self test

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
LOGFILE="${OUTPUT}/kselftest.txt"
KSELFTEST_PATH="/opt/kselftests/mainline/"

SCRIPT="$(readlink -f "${0}")"
SCRIPTPATH="$(dirname "${SCRIPT}")"
# List of known unsupported test cases to be skipped
SKIPFILE=""
# List of test cases to be skipped in yaml/skipgen format
SKIPFILE_YAML=""
BOARD=""
BRANCH=""
ENVIRONMENT=""
SKIPLIST=""
TESTPROG_URL=""
TST_CMDFILES=""
TST_CASENAME=""
SHARD_NUMBER=1
SHARD_INDEX=1

# Architecture-specific tarball name defaults.
if [ "$(uname -m)" = "aarch64" ]; then
    TESTPROG="kselftest_aarch64.tar.gz"
else
    TESTPROG="kselftest_armhf.tar.gz"
fi

usage() {
    echo "Usage: $0 [-i sharding bucket to run ]
                    [-n number of shard buckets to create ]
                    [-c bpf cpufreq net timers]
                    [-T cpu-hotplug:cpu-on-off-test.sh]
                    [-t kselftest_aarch64.tar.gz | kselftest_armhf.tar.gz]
                    [-s True|False]
                    [-u url]
                    [-p path]
                    [-L List of skip test cases]
                    [-S kselftest-skipfile]
                    [-b board]
                    [-g branch]
                    [-e environment]" 1>&2
    exit 1
}

while getopts "i:n:c:T:t:s:u:p:L:S:b:g:e:h" opt; do
    case "${opt}" in
        i) SHARD_INDEX="${OPTARG}" ;;
        n) SHARD_NUMBER="${OPTARG}" ;;
        c) TST_CMDFILES="${OPTARG}" ;;
        T) TST_CASENAME="${OPTARG}" ;;
        t) TESTPROG="${OPTARG}" ;;
        s) SKIP_INSTALL="${OPTARG}" ;;
        # Download kselftest tarball from given URL
        u) TESTPROG_URL="${OPTARG}" ;;
        # List of known unsupported test cases to be skipped
        L) SKIPLIST="${OPTARG}" ;;
        p) KSELFTEST_PATH="${OPTARG}" ;;
        S)

           #OPT=$(echo "${OPTARG}" | grep "http")
           #if [ -z "${OPT}" ] ; then
           ## kselftest skipfile
           #  SKIPFILE="${SCRIPTPATH}/${OPTARG}"
           #else
           ## Download kselftest skipfile from speficied URL
           #  wget "${OPTARG}" -O "skipfile"
           #  SKIPFILE="skipfile"
           #  SKIPFILE="${SCRIPTPATH}/${SKIPFILE}"
           #fi

           if [ -z "${OPTARG##*http*}" ]; then
             if [ -z "${OPTARG##*yaml*}" ]; then
               # Skipfile is of type yaml
               SKIPFILE_TMP="http-skipfile.yaml"
               SKIPFILE_YAML="${SCRIPTPATH}/${SKIPFILE_TMP}"
             else
               # Skipfile is normal skipfile
               SKIPFILE_TMP="http-skipfile"
               SKIPFILE="${SCRIPTPATH}/${SKIPFILE_TMP}"
             fi
             # Download LTP skipfile from specified URL
             if ! wget "${OPTARG}" -O "${SKIPFILE_TMP}"; then
               error_msg "Failed to fetch ${OPTARG}"
               exit 1
             fi
           elif [ "${OPTARG##*.}" = "yaml" ]; then
             # yaml skipfile; use skipgen to generate a skipfile
             SKIPFILE_YAML="${SCRIPTPATH}/${OPTARG}"
           else
             # Regular LTP skipfile
             SKIPFILE="${SCRIPTPATH}/${OPTARG}"
           fi
           ;;

        b)
            export BOARD="${OPTARG}"
            ;;
        g)
            export BRANCH="${OPTARG}"
            ;;
        e)
            export ENVIRONMENT="${OPTARG}"
            ;;
        h|*) usage ;;
    esac
done

# If no explicit URL given, use the default URL for the kselftest tarball.
if [ -z "${TESTPROG_URL}" ]; then
    TESTPROG_URL=http://testdata.validation.linaro.org/tests/kselftest/"${TESTPROG}"
fi

if [ -n "${SKIPFILE_YAML}" ]; then
    export SKIPFILE_PATH="${SCRIPTPATH}/generated_skipfile"
    generate_skipfile
    if [ ! -f "${SKIPFILE_PATH}" ]; then
        error_msg "Skipfile ${SKIPFILE} does not exist";
        exit 1
    fi
    SKIPFILE="${SKIPFILE_PATH}"
fi


parse_output() {
    ./parse-output.py < "${LOGFILE}" | tee -a "${RESULT_FILE}"
}

install() {
    dist_name
    # shellcheck disable=SC2154
    case "${dist}" in
        debian|ubuntu) install_deps "sed perl wget xz-utils iproute2 python3-tap" "${SKIP_INSTALL}" ;;
        centos|fedora) install_deps "sed perl wget xz iproute" "${SKIP_INSTALL}" ;;
        unknown) warn_msg "Unsupported distro: package install skipped" ;;
    esac
}

! check_root && error_msg "You need to be root to run this script."
saved_pwd=$(pwd)
create_out_dir "${OUTPUT}"

install

if [ -d "${KSELFTEST_PATH}" ]; then
    echo "kselftests found on rootfs"
    # shellcheck disable=SC2164
    cd "${KSELFTEST_PATH}" || exit
else
    # Fetch whatever we have been aimed at, assuming only that it can
    # be handled by "tar". Do not assume anything about the compression.
    wget "${TESTPROG_URL}" -O "${TESTPROG}"
    tar -xaf "${TESTPROG}"
    # shellcheck disable=SC3044
    if [ ! -e "run_kselftest.sh" ]; then cd "kselftest" || exit; fi
fi

skips=$(mktemp -p . -t skip-XXXXXX)

if [ -n "${SKIPLIST}" ]; then
    # shellcheck disable=SC2086
    for skip_regex in ${SKIPLIST}; do
	echo "${skip_regex}" >> "$skips"
    done
fi

# Ignore SKIPFILE when SKIPLIST provided
if [ -f "${SKIPFILE}" ] &&  [ -z "${SKIPLIST}" ]; then
    while read -r skip_regex; do
        case "${skip_regex}" in \#*) continue ;; esac
	echo "${skip_regex}" >> "$skips"
    done < "${SKIPFILE}"
fi

cp kselftest-list.txt kselftest-list.txt.orig
echo "skiplist:"
echo "========================================"
while read -r skip_regex; do
    echo "$skip_regex"
    # Remove matching tests from list of tests to run and report it as skipped
    perl -i -ne 'if (s|^('"${skip_regex}"')$|\1 skip|) { print STDERR; } else { print; }' kselftest-list.txt 2>>"${RESULT_FILE}"
done < "${skips}"
echo "========================================"
rm -f "${skips}"

if [ -n "${TST_CASENAME}" ]; then
    ./run_kselftest.sh -t "${TST_CASENAME}" 2>&1 | tee -a "${LOGFILE}"
elif [ -n "${TST_CMDFILES}" ]; then
    cp kselftest-list.txt kselftest-list.txt.original
    # shellcheck disable=SC2086
    for test in ${TST_CMDFILES}; do
        cp kselftest-list.txt.original kselftest-list.txt
        grep "^${test}:" kselftest-list.txt | tee kselftest-list.tmp
        split --verbose --numeric-suffixes=1 -n l/"${SHARD_INDEX}"/"${SHARD_NUMBER}" kselftest-list.tmp > shardfile
        echo "============== Tests to run ==============="
        cat shardfile
        echo "===========End Tests to run ==============="
        if [ -s shardfile ]; then
            report_pass "shardfile-${test}"
        else
            report_fail "shardfile-${test}"
            continue
        fi
        cp shardfile kselftest-list.txt
        ./run_kselftest.sh -c ${test} 2>&1 | tee -a "${LOGFILE}"
    done
    cp kselftest-list.txt.original kselftest-list.txt
else
    ./run_kselftest.sh 2>&1 | tee "${LOGFILE}"
fi
# shellcheck disable=SC2164
cd "$saved_pwd" || exit
parse_output
