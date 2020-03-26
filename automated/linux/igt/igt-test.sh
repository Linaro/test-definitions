#!/bin/bash

RESULT_LOG="result.log"
DUMP_FRAMES_DIR="/root/dump-frames"

generate_igtrc() {
cd "$HOME" || exit 1

mkdir -p "${DUMP_FRAMES_DIR}"

cat > ".igtrc" <<-EOF
[Common]
FrameDumpPath=${DUMP_FRAMES_DIR}
[DUT]
SuspendResumeDelay=15
[Chamelium]
URL=http://${CHAMELIUM_IP}:9992
[Chamelium:${HDMI_DEV_NAME}]
ChameliumPortID=3
EOF

cd - > /dev/null 2>&1 || exit 1
}

generate_chamelium_testlist() {
    echo "Generate Chamelium test list"
    TEST_LIST=igt-chamelium-test.testlist
    # Skip Display Port/VGA and Suspend/Hibrnate related tests
    ${TEST_SCRIPT} -l | grep chamelium | grep -v "dp\|vga\|suspend\|hibernate" | tee "${IGT_DIR}"/"${TEST_LIST}"
}

download_piglit() {
    # Download Piglit
    git config --global http.postBuffer 157286400
    if [ ! -d "${IGT_DIR}/piglit" ]; then
        echo "Download Piglit.."
        time ${TEST_SCRIPT} -d
    fi
}

usage() {
    echo "usage: $0 -d <igt-gpu-tools dir> -t <test-list> [-c <chamelium ip address>] [-h <HDMI device name>]" 1>&2
    exit 1
}

while getopts ":c:h:d:t:" opt; do
    case "${opt}" in
        c) CHAMELIUM_IP="${OPTARG}" ;;
        h) HDMI_DEV_NAME="${OPTARG}" ;;
        d) IGT_DIR="${OPTARG}" ;;
        t) TEST_LIST="${OPTARG}" ;;
        *) usage ;;
    esac
done

if [ -z "${IGT_DIR}" ] || [ -z "${TEST_LIST}" ]; then
    usage
fi

if [ "${TEST_LIST}" == "CHAMELIUM" ] && [ -z "${CHAMELIUM_IP}" ] || [ -z "${HDMI_DEV_NAME}" ]; then
    usage
fi

TEST_SCRIPT="${IGT_DIR}/scripts/run-tests.sh"

export IGT_TEST_ROOT="/usr/libexec/igt-gpu-tools"

if [ ! -f "${IGT_DIR}/runner/igt_runner" ]; then
    ${TEST_SCRIPT} --help | grep -q '\-p' && TEST_SCRIPT="${TEST_SCRIPT} -p"
    download_piglit
fi

if [ "${TEST_LIST}" == "CHAMELIUM" ]; then
    echo "Going to run igt Chamelium test"
    if [ ! -f "$HOME/.igtrc" ]; then
        echo "Generate ~/.igtrc"
        generate_igtrc
    fi
    generate_chamelium_testlist
else
    echo "Going to run ${TEST_LIST}"
    cp "${TEST_LIST}" "${IGT_DIR}"
fi

# Run tests
echo "Run ${TEST_LIST}"
${TEST_SCRIPT} -T "${IGT_DIR}"/"${TEST_LIST}" -v | tee tmp.log
grep -e '^pass' -e '^skip' -e '^fail' tmp.log|awk -F':\ ' '{print $2" "$1}' > ${RESULT_LOG}
