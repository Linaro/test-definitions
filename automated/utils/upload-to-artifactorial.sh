#!/bin/sh

ATTACHMENT=""
URL=""
TOKEN=""
RESULT_FILE="$(pwd)/output/result.txt"

usage() {
    echo "Usage: $0 [-a <attachment>] [-u <url>] [-t <token>]" 1>&2
    exit 1
}

while getopts ":a:u:t:" opt; do
    case "${opt}" in
        a) ATTACHMENT="${OPTARG}" ;;
        u) URL="${OPTARG}" ;;
        t) TOKEN="${OPTARG}" ;;
        *) usage ;;
    esac
done

if [ -z "${URL}" ]; then
    echo "test-attachment skip" | tee -a "${RESULT_FILE}"
    exit 0
fi

if [ -z "${TOKEN}" ]; then
    return=$(curl -F "path=@${ATTACHMENT}" "${URL}")
else
    return=$(curl -F "path=@${ATTACHMENT}" -F "token=${TOKEN}" "${URL}")
fi

if echo "${return}" | grep "${ATTACHMENT}"; then
    if which lava-test-reference; then
        lava-test-reference "test-attachment" --result "pass" --reference "https://archive.validation.linaro.org/artifacts/${return}"
    else
        echo "test-attachment skip" | tee -a "${RESULT_FILE}"
    fi
else
    echo "test-attachment fail" | tee -a "${RESULT_FILE}"
fi
