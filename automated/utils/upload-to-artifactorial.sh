#!/bin/sh

ATTACHMENT=""
URL=""
ARTIFACTORIAL_TOKEN=""
CURL_VERBOSE_FLAG=""
FAILURE_RETURN_VALUE=0

usage() {
    echo "Usage: $0 [-a <attachment>] [-u <artifactorial_url>] [-t <artifactorial_token>] [-v] [-r]" 1>&2
    echo "  -a attachment           Path to the file to upload" 1>&2
    echo "  -u artifactorial_url    URL to the folder in Artifactorial to upload to" 1>&2
    echo "  -t artifactorial_token  Access token for Artifactorial. This script will try to fetch" 1>&2
    echo "                          the token from (lava_test_dir)/secrets. If this file exists," 1>&2
    echo "                          it overrides this parameter." 1>&2
    echo "  -v      Pass -v (verbose) flag to curl for debugging." 1>&2
    echo "  -r      Report failure. If the upload fails and this flag is set, the script will exit" 1>&2
    echo "          with return value 1. If the upload is skipped (no URL or no token specified)," 1>&2
    echo "          this script will still return 0." 1>&2
    exit 1
}

while getopts ":a:u:t:vr" opt; do
    case "${opt}" in
        a) ATTACHMENT="${OPTARG}" ;;
        u) URL="${OPTARG}" ;;
        t) ARTIFACTORIAL_TOKEN="${OPTARG}" ;;
        v) CURL_VERBOSE_FLAG="-v" ;;
        r) FAILURE_RETURN_VALUE=1 ;;
        *) usage ;;
    esac
done

if [ -z "${URL}" ]; then
    echo "test-attachment skip"
    command -v lava-test-case > /dev/null 2>&1 && lava-test-case "test-attachment" --result "skip"
    exit 0
fi

if command -v lava-test-reference > /dev/null 2>&1; then
    # If 'ARTIFACTORIAL_TOKEN' defined in 'secrects' dictionary defined in job
    # definition file, it will be used.
    lava_test_dir="$(find /lava-* -maxdepth 0 -type d | grep -E '^/lava-[0-9]+' 2>/dev/null | sort | tail -1)"
    if test -f "${lava_test_dir}/secrets" && grep -q "_TOKEN" "${lava_test_dir}/secrets"; then
        # shellcheck disable=SC1090
        . "${lava_test_dir}/secrets"
    fi

    if [ -n "${ARTIFACTORIAL_TOKEN}" ]; then
        return=$(curl ${CURL_VERBOSE_FLAG} -F "path=@${ATTACHMENT}" -F "token=${ARTIFACTORIAL_TOKEN}" "${URL}")
    elif [ -n "${SQUAD_ARCHIVE_SUBMIT_TOKEN}" ]; then
        squad_testrun_id=$(curl ${CURL_VERBOSE_FLAG} --header "Auth-Token: ${SQUAD_ARCHIVE_SUBMIT_TOKEN}" --form "attachment=@${ATTACHMENT}" "${URL}")
        # URL will be in the format like this:
        #    https://qa-reports.linaro.org/api/submit/squad_group/squad_project/squad_build/environment
        url_squad=$(echo "${URL}"|sed 's|/api/submit/.*||')
        return="${url_squad}/api/testruns/${squad_testrun_id}/attachments/?filename=${attachmentBasename}"
        if ! echo "${return}" | grep -E "^[0-9]+$"; then
            return="${squad_testrun_id}"
        fi
    else
        echo "WARNING: ARTIFACTORIAL_TOKEN or SQUAD_ARCHIVE_SUBMIT_TOKEN is empty! File uploading skipped."
        echo "test-attachment skip"
        command -v lava-test-case > /dev/null 2>&1 && lava-test-case "test-attachment" --result "skip"
        exit 0
    fi

    attachmentBasename="$(basename "${ATTACHMENT}")"
    if echo "${return}" | grep "${attachmentBasename}"; then
        lava-test-reference "test-attachment" --result "pass" --reference "${return}"
    else
        echo "test-attachment fail"
        echo "Expected the basename of the attachment file (\"${attachmentBasename}\") to be part \
of the ${URL}, but curl returned \"${return}\"."
        command -v lava-test-case > /dev/null 2>&1 && lava-test-case "test-attachment" --result "fail"
        exit "${FAILURE_RETURN_VALUE}"
    fi
else
    echo "test-attachment skip"
    command -v lava-test-case > /dev/null 2>&1 && lava-test-case "test-attachment" --result "skip"
fi
