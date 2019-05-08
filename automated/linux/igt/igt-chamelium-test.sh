#!/bin/bash

RESULT_LOG="result.log"

generate_igtrc() {
cd "$HOME" || exit 1

mkdir -p /root

cat > ".igtrc" <<-EOF
[Common]
FrameDumpPath=/root/
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
    echo "Generate test list"
    TEST_LIST=igt-chamelium-test.testlist
    # Skip Display Port/VGA and Suspend/Hibrnate related tests
    ${TEST_SCRIPT} -l | grep chamelium | grep -v "dp\|vga\|suspend\|hibernate" | tee "${IGT_DIR}"/"${TEST_LIST}"
}

usage() {
    echo "usage: $0 -c <chamelium ip address> -h <HDMI device name> -d <igt-gpu-tools dir> [-t <test-list>]" 1>&2
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

if [ -z "${CHAMELIUM_IP}" ] || [ -z "${HDMI_DEV_NAME}" ] || [ -z "${IGT_DIR}" ]; then
    usage
fi

TEST_SCRIPT="${IGT_DIR}/scripts/run-tests.sh"

# generate ~/.igtrc
if [ ! -f "$HOME/.igtrc" ]; then
    echo "Generate ~/.igtrc"
    generate_igtrc
fi
# Download Piglit
git config --global http.postBuffer 1048576000
if [ ! -d "${IGT_DIR}/piglit" ]; then
    echo "Download Piglit.."
    ${TEST_SCRIPT} -d
fi
# If test list is not assigned, generate it
if [ -z "${TEST_LIST}" ]; then
    generate_chamelium_testlist
fi

# Run tests
echo "Run ${TEST_LIST}"
${TEST_SCRIPT} -T "${IGT_DIR}"/"${TEST_LIST}" -v | tee tmp.log
grep -e '^pass' -e '^skip' -e '^fail' tmp.log|awk -F':\ ' '{print $2" "$1}' > ${RESULT_LOG}
