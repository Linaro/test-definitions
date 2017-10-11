#!/bin/sh

ATTACHMENT=""
ARTIFACTORIAL_URL=""
ARTIFACTORIAL_TOKEN=""

usage() {
    echo "Usage: $0 [-a <attachment>] [-u <artifactorial_url>] [-t <artifactorial_token>]" 1>&2
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
    echo "test-attachment skip"
    which lava-test-case && lava-test-case "test-attachment" --result "skip"
    exit 0
fi

if which lava-test-reference; then
    # If 'ARTIFACTORIAL_TOKEN' defined in 'secrects' dictionary defined in job
    # definition file, it will be used.
    lava_test_dir="$(find /lava-* -maxdepth 0 -type d -regex '/lava-[0-9]+' 2>/dev/null | sort | tail -1)"
    if test -f "${lava_test_dir}/secrets" && grep -q "ARTIFACTORIAL_TOKEN" "${lava_test_dir}/secrets"; then
        # shellcheck disable=SC1090
        . "${lava_test_dir}/secrets"
    fi

    if [ -z "${ARTIFACTORIAL_TOKEN}" ]; then
        echo "WARNING: ARTIFACTORIAL_TOKEN is empty! File uploading skipped."
        echo "test-attachment skip"
        which lava-test-case && lava-test-case "test-attachment" --result "skip"
        exit 0
    else
        return=$(curl -F "path=@${ATTACHMENT}" -F "token=${ARTIFACTORIAL_TOKEN}" "${ARTIFACTORIAL_URL}")
    fi

    if echo "${return}" | grep "$(basename "${ATTACHMENT}")"; then
        lava-test-reference "test-attachment" --result "pass" --reference "${return}"
    else
        echo "test-attachment fail"
        which lava-test-case && lava-test-case "test-attachment" --result "fail"
    fi
else
    echo "test-attachment skip"
    which lava-test-case && lava-test-case "test-attachment" --result "skip"
fi
