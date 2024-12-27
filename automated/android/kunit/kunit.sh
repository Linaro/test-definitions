#!/bin/bash -ex

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
DIR_OUTPUT="$(pwd)/output"
mkdir -p "${DIR_OUTPUT}"
RESULT_FILE="${DIR_OUTPUT}/result.txt"
export RESULT_FILE

# shellcheck disable=SC1091
. ../../lib/android-test-lib

RETRY_COUNT=5
RETRY_INTERVAL=2

TESTS_ZIP_URL=""
SQUAD_UPLOAD_URL=""
TRADEFED_PREBUILTS_GIT_URL="https://android.googlesource.com/platform/tools/tradefederation/prebuilts"

F_TESTS_ZIP="$(pwd)/tests.zip"
DIR_TESTS="$(pwd)/tests"
DIR_TEST_LOGS="${DIR_OUTPUT}/test-logs"
F_KUNIT_LOG="${DIR_TEST_LOGS}/kunit.log"
DIR_TF_PREBUILTS="$(pwd)/prebuilts"

function usage(){
    echo "Usage: $0 -u <TESTS_ZIP_URL> [ -s <SQUAD_UPLOAD_URL>]" 1>&2
    exit 1
}

function upload_logs_to_squad(){
    if [ -z "${SQUAD_UPLOAD_URL}" ]; then
        return
    fi
    # Upload test log and result files to artifactorial.
    name_dir_output=$(basename "${DIR_OUTPUT}")
    if ! tar caf "kunit-output-$(date +%Y%m%d%H%M%S).tar.xz" "${name_dir_output}"; then
         error_fatal "tradefed - failed to collect results and log files [$ANDROID_SERIAL]"
    fi
    ATTACHMENT=$(ls kunit-output-*.tar.xz)
    ../../utils/upload-to-squad.sh -a "${ATTACHMENT}" -u "${SQUAD_UPLOAD_URL}"
}

function parse_kunit_log(){
    local f_kunit_log="${1}"
    local f_kunit_stub_log="${DIR_TEST_LOGS}/kunit_stub.log"

    if [ -z "${f_kunit_log}" ] || [ ! -f "${f_kunit_log}" ]; then
        echo "KUnit log does not exist"
        return
    fi
    # grep the stub log to a single file and parsing the results
    # 20:43:20 stub: soc-utils-test.soc-utils#test_snd_soc_params_to_bclk: PASSED (0ms)
    # 00:21:09 stub: kunit-example-test.example_init#example_init_test: PASSED (0ms)
    #  | cut -d: -f4- \            # kunit-example-test.example_init#example_init_test: PASSED (0ms)
    #  | tr -d ':' \               # kunit-example-test.example_init#example_init_test PASSED (0ms)
    #  | awk '{print $1, $2}' \    # kunit-example-test.example_init#example_init_test PASSED
    #  | sort | uniq \             # to filter out the duplication of FAILURE in Result Summary part
    grep "stub:" "${f_kunit_log}" \
        | cut -d: -f4- \
        | tr -d ':' \
        | awk '{print $1, $2}' \
        | sort | uniq \
        > "${f_kunit_stub_log}"
    while read -r line; do
        # kunit-example-test.example_init#example_init_test PASSED
        # kunit-example-test.example#example_skip_test IGNORED
        # soc-utils-test#soc-utils-test FAILURE
        test_case_name=$(echo "${line}"|awk '{print $1}')
        test_case_result=$(echo "${line}"|awk '{print $2}')

        # reformat the test case name to avoid potential confusions
        # being caused by some special characters
        test_case_name=$(echo "${test_case_name}" \
                            | tr -c '#@/+,[:alnum:]:.-' '_' \
                            | tr -s '_' \
                            | sed 's/_$//' \
                            )

        case "X${test_case_result}" in
            "XPASSED")
                report_pass "${test_case_name}"
                ;;
            "XIGNORED")
                report_skip "${test_case_name}"
                ;;
            "XFAILURE")
                report_fail "${test_case_name}"
                ;;
            *)
                report_unknown "${test_case_name}"
                ;;
        esac
    done < "${f_kunit_stub_log}"
}

while getopts "u:s:h" o; do
  case "$o" in
    u) TESTS_ZIP_URL="${OPTARG}" ;;
    s) SQUAD_UPLOAD_URL="${OPTARG}" ;;
    h|*) usage ;;
  esac
done

# export ANDROID_SERIAL
initialize_adb

if [ -z "${TESTS_ZIP_URL}" ]; then
    echo "The TESTS_ZIP_URL must be specified."
    exit 1
fi

# download and unzip tests.zip
rm -f "${F_TESTS_ZIP}" && \
    curl --retry "${RETRY_COUNT}" --retry-delay "${RETRY_INTERVAL}" -fsSL "${TESTS_ZIP_URL}" -o "${F_TESTS_ZIP}"
rm -fr "${DIR_TESTS}" && \
    mkdir -p "${DIR_TESTS}" && \
    unzip -o "${F_TESTS_ZIP}" -d "${DIR_TESTS}"

# clone the tradefed prebuilts repository
i=1
while [ $i -le "${RETRY_COUNT}" ]; do
    rm -fr "${DIR_TF_PREBUILTS}"
    if git clone --depth 1 "${TRADEFED_PREBUILTS_GIT_URL}" "${DIR_TF_PREBUILTS}"; then
        break
    fi

    # try again in ${RETRY_INTERVAL} seconds
    sleep "${RETRY_INTERVAL}"
    i=$((i + 1))
done

# run the kunit test
mkdir -p "${DIR_TEST_LOGS}"
prebuilts/filegroups/tradefed/tradefed.sh  \
    run commandAndExit \
    template/local_min \
    --template:map test=suite/test_mapping_suite \
    --include-filter kunit \
    --tests-dir="${DIR_TESTS}"  \
    --log-file-path="${DIR_TEST_LOGS}" \
    -s "${ANDROID_SERIAL}" |& tee "${F_KUNIT_LOG}"

parse_kunit_log "${F_KUNIT_LOG}"

upload_logs_to_squad
