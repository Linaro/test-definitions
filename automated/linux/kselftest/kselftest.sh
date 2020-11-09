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

# Architecture-specific tarball name defaults.
if [ "$(uname -m)" = "aarch64" ]; then
    TESTPROG="kselftest_aarch64.tar.gz"
else
    TESTPROG="kselftest_armhf.tar.gz"
fi

usage() {
    echo "Usage: $0 [-t kselftest_aarch64.tar.gz | kselftest_armhf.tar.gz]
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

while getopts "t:s:u:p:L:S:b:g:e:h" opt; do
    case "${opt}" in
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
    perl -ne '
    if (m|^# selftests: (.*)$|) {
	$testdir = $1;
	$testdir =~ s|[:/]\s*|.|g;
    } elsif (m|^(?:# )*(not )?ok (?:\d+) ([^#]+)(# (SKIP)?)?|) {
        $not = $1;
        $test = $2;
        $skip = $4;
        $test =~ s|\s+$||;
        # If the test name starts with "selftests: " it is "fully qualified".
        if ($test =~ /selftests: (.*)/) {
            $test = $1;
	    $test =~ s|[:/]\s*|.|g;
        } else {
            # Otherwise, it likely needs the testdir prepended.
            $test = "$testdir.$test";
        }
        # Any appearance of the SKIP is a skip.
        if ($skip eq "SKIP") {
            $result="skip";
        } elsif ($not eq "not ") {
            $result="fail";
        } else {
            $result="pass";
        }
	print "$test $result\n";
    }
' "${LOGFILE}" >> "${RESULT_FILE}"
}

install() {
    dist_name
    # shellcheck disable=SC2154
    case "${dist}" in
        debian|ubuntu) install_deps "sed perl wget xz-utils iproute2" "${SKIP_INSTALL}" ;;
        centos|fedora) install_deps "sed perl wget xz iproute" "${SKIP_INSTALL}" ;;
        unknown) warn_msg "Unsupported distro: package install skipped" ;;
    esac
}

! check_root && error_msg "You need to be root to run this script."
create_out_dir "${OUTPUT}"
# shellcheck disable=SC2164
cd "${OUTPUT}"

install

if [ -d "${KSELFTEST_PATH}" ]; then
    echo "kselftests found on rootfs"
    # shellcheck disable=SC2164
    cd "${KSELFTEST_PATH}"
else
    # Fetch whatever we have been aimed at, assuming only that it can
    # be handled by "tar". Do not assume anything about the compression.
    wget "${TESTPROG_URL}"
    tar -xaf "$(basename "${TESTPROG_URL}")"
    # shellcheck disable=SC2164
    if [ ! -e "run_kselftest.sh" ]; then cd "kselftest"; fi
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

echo "========================================"
echo "skiplist:"
while read -r skip_regex; do
	echo "${skip_regex}"
	perl -pi -e '
# Discover top-level test directory from: cd TESTDIR
$testdir=$1 if m|^cd ([^\$]+)\b|;
# Process each test from: \t"TESTNAME"
if (m|^\t"([^"]+)"|) {
	$test = $1;
	# If the test_regex matches TESTDIR/TESTNAME,
	# remove it from the run script.
	$name = "$testdir/$test";
	if ("$name" =~ m|^'"${skip_regex}"'$|) {
		s|^\t"[^"]+"|\t|;
		$name =~ s|/|.|g;
		# Record each skipped test as having been skipped.
		open(my $fd, ">>'"${RESULT_FILE}"'");
		print $fd "$name skip\n";
		close($fd);
	}
}' run_kselftest.sh
done < "${skips}"
echo "========================================"
rm -f "${skips}"

# run_kselftest.sh file generated by kselftest Makefile and included in tarball
./run_kselftest.sh 2>&1 | tee "${LOGFILE}"
parse_output
