#!/bin/sh

ATTACHMENT=""
ARTIFACTORIAL_URL=""
CURL_VERBOSE_FLAG=""
FAILURE_RETURN_VALUE=0
RETRY_COUNT=5
RETRY_INTERVAL=30

usage() {
    echo "Usage: $0 [-a <attachment>] [-u <artifactorial_url>] [-c <retry_count>] [-i <retry_interval>] [-v] [-r]" 1>&2
    echo "  -a attachment           Path to the file to upload" 1>&2
    echo "  -u squad_url            SQUAD_URL where the attachment will be uploaded to" 1>&2
    echo "                          This script will try to fetch the SQUAD_ARCHIVE_SUBMIT_TOKEN" 1>&2
    echo "                          token from (lava_test_dir)/secrets or environments for the upload." 1>&2
    echo "  -c retry_count          How many times to try when the uploading failed" 1>&2
    echo "  -i retry_interval       The interval seconds between the re-tries." 1>&2
    echo "  -v      Pass -v (verbose) flag to curl for debugging." 1>&2
    echo "  -r      Report failure. If the upload fails and this flag is set, the script will exit" 1>&2
    echo "          with return value 1. If the upload is skipped (no URL or no token found)," 1>&2
    echo "          this script will still return 0." 1>&2
    exit 1
}

while getopts ":a:u:c:i:vr" opt; do
    case "${opt}" in
        a) ATTACHMENT="${OPTARG}" ;;
        u) ARTIFACTORIAL_URL="${OPTARG}" ;;
        c) RETRY_COUNT="${OPTARG}" ;;
        i) RETRY_INTERVAL="${OPTARG}" ;;
        v) CURL_VERBOSE_FLAG="-v" ;;
        r) FAILURE_RETURN_VALUE=1 ;;
        *) usage ;;
    esac
done

if [ -z "${ARTIFACTORIAL_URL}" ]; then
    echo "test-attachment skip"
    command -v lava-test-case > /dev/null 2>&1 && lava-test-case "test-attachment" --result "skip"
    exit 0
fi

if command -v lava-test-reference > /dev/null 2>&1; then
    # The 'SQUAD_ARCHIVE_SUBMIT_TOKEN' needs to be defined in 'secrects' dictionary in job
    # definition file, or defined in the environment, it will be used.
    # One issue here Milosz pointed out:
    #    If there is lava_test_results_dir set in the job context, "/lava-*" might not be correct.
    lava_test_dir="$(find /lava-* -maxdepth 0 -type d | grep -E '^/lava-[0-9]+' 2>/dev/null | sort | tail -1)"
    if test -f "${lava_test_dir}/secrets"; then
        # shellcheck disable=SC1090
        . "${lava_test_dir}/secrets"
    fi

    if [ -z "${SQUAD_ARCHIVE_SUBMIT_TOKEN}" ]; then
        echo "WARNING: SQUAD_ARCHIVE_SUBMIT_TOKEN is empty! File uploading skipped."
        echo "test-attachment skip"
        command -v lava-test-case > /dev/null 2>&1 && lava-test-case "test-attachment" --result "skip"
        exit 0
    fi

    attachmentBasename="$(basename "${ATTACHMENT}")"
    # Re-run the upload for ${RETRY_COUNT} times with the interval of ${RETRY_INTERVAL} seconds when it fails
    i=1
    while [ $i -le "${RETRY_COUNT}" ]; do
        # response is the squad testrun id when succeed
        response=$(curl ${CURL_VERBOSE_FLAG} --header "Authorization: token ${SQUAD_ARCHIVE_SUBMIT_TOKEN}" --form "attachment=@${ATTACHMENT}" "${ARTIFACTORIAL_URL}")

        # generate the SQUAD url for download and report pass when uploading succeed
        if echo "${response}" | grep -E "^[0-9]+$"; then
            # ARTIFACTORIAL_URL will be in the format like this:
            #    https://qa-reports.linaro.org/api/submit/squad_group/squad_project/squad_build/environment
            url_squad=$(echo "${ARTIFACTORIAL_URL}"|sed 's|/api/submit/.*||')
            url_uploaded="${url_squad}/api/testruns/${response}/attachments/?filename=${attachmentBasename}"
            lava-test-reference "test-attachment" --result "pass" --reference "${url_uploaded}"
            break
        fi

        # still print the output every time for investigation purpose
        echo "Expected one SQUAD testrun id returend, but curl returned \"${response}\"."

        # report fail if the uploading failed for ${RETRY_COUNT} times
        if [ $i -eq "${RETRY_COUNT}" ]; then
            echo "test-attachment fail"
            command -v lava-test-case > /dev/null 2>&1 && lava-test-case "test-attachment" --result "fail"
            exit "${FAILURE_RETURN_VALUE}"
        fi

        # try again in ${RETRY_INTERVAL} seconds
        sleep "${RETRY_INTERVAL}"
        i=$((i + 1))
    done
else
    echo "test-attachment skip"
    command -v lava-test-case > /dev/null 2>&1 && lava-test-case "test-attachment" --result "skip"
fi
