#!/bin/sh

ATTACHMENT=""
ARTIFACTORIAL_URL=""
ARTIFACTORIAL_TOKEN=""
RESULT_FILE="$(pwd)/output/result.txt"

usage() {
    echo "Usage: $0 [-a <attachment>] [-u <url>] [-t <artifactorial_token>]" 1>&2
    exit 1
}

while getopts ":a:u:t:" opt; do
    case "${opt}" in
        a) ATTACHMENT="${OPTARG}" ;;
        u) ARTIFACTORIAL_URL="${OPTARG}" ;;
        t) ARTIFACTORIAL_TOKEN="${OPTARG}" ;;
        *) usage ;;
    esac
done

if [ -z "${ARTIFACTORIAL_URL}" ]; then
    echo "test-attachment skip" | tee -a "${RESULT_FILE}"
    exit 0
fi

if which lava-test-reference; then
    # If 'ARTIFACTORIAL_TOKEN' defined in 'secrects' dictionary defined in job
    # definition file, it will be used.
    lava_test_dir="$(find /lava-* -maxdepth 0 -type d 2>/dev/null | sort | tail -1)"
    if test -f "${lava_test_dir}/secrets" && grep -q "ARTIFACTORIAL_TOKEN" "${lava_test_dir}/secrets"; then
        # shellcheck disable=SC1090
        . "${lava_test_dir}/secrets"
    fi

    if [ -z "${ARTIFACTORIAL_TOKEN}" ]; then
        return=$(curl -F "path=@${ATTACHMENT}" "${ARTIFACTORIAL_URL}")
    else
        return=$(curl -F "path=@${ATTACHMENT}" -F "token=${ARTIFACTORIAL_TOKEN}" "${ARTIFACTORIAL_URL}")
    fi

    if echo "${return}" | grep "$(basename "${ATTACHMENT}")"; then
        lava-test-reference "test-attachment" --result "pass" --reference "https://archive.validation.linaro.org/artifacts/${return}"
    else
        echo "test-attachment fail" | tee -a "${RESULT_FILE}"
    fi
else
    echo "test-attachment skip" | tee -a "${RESULT_FILE}"
fi
