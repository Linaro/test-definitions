#!/bin/sh -ex
# shellcheck disable=SC1090

TEST_DIR=$(dirname "$(realpath "$0")")
OUTPUT="${TEST_DIR}/output"
SKIP_INSTALL="false"

WA_TAG="master"
WA_GIT_REPO="https://github.com/ARM-software/workload-automation"
WA_TEMPLATES_REPO="https://git.linaro.org/qa/wa2-lava.git"
TEMPLATES_BRANCH="wa-templates"
CONFIG="config/generic-linux-localhost.py"
AGENDA="agenda/linux-dhrystone.yaml"
DEVLIB_REPO="https://github.com/ARM-software/devlib.git"
DEVLIB_TAG="master"

usage() {
    echo "Usage: $0 [-s <true|false>] [-t <wa_tag>] [-r <wa_templates_repo>] [-T <templates_branch>] [-c <config>] [-a <agenda>] [-o <output_dir> ] [-R <wa_git_repository>] [-d <devlib_repo>] [-D <devlib_tag>]" 1>&2
    exit 1
}

while getopts ":s:t:r:T:c:a:o:R:D:d:" opt; do
    case "${opt}" in
        s) SKIP_INSTALL="${OPTARG}" ;;
        t) WA_TAG="${OPTARG}" ;;
        r) WA_TEMPLATES_REPO="${OPTARG}" ;;
        T) TEMPLATES_BRANCH="${OPTARG}" ;;
        c) CONFIG="${OPTARG}" ;;
        a) AGENDA="${OPTARG}" ;;
        R) WA_GIT_REPO="${OPTARG}" ;;
        o) NEW_OUTPUT="${OPTARG}" ;;
        D) DEVLIB_TAG="${OPTARG}" ;;
        d) DEVLIB_REPO="${OPTARG}" ;;
        *) usage ;;
    esac
done

. "${TEST_DIR}/../../lib/sh-test-lib"

! check_root && error_msg "Please run this test as root."
cd "${TEST_DIR}"
if [ ! -z "${NEW_OUTPUT}" ]; then
    OUTPUT="${NEW_OUTPUT}"
fi
create_out_dir "${OUTPUT}"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE

if [ "${SKIP_INSTALL}" = "true" ] || [ "${SKIP_INSTALL}" = "True" ]; then
    info_msg "WA installation skipped"
else
    PKGS="git wget zip tar xz-utils python python-yaml python-lxml python-setuptools python-numpy python-colorama python-pip sqlite3 time sysstat openssh-client openssh-server sshpass python-jinja2 curl"
    install_deps "${PKGS}"
    pip install --upgrade --quiet pip && hash -r
    pip install --upgrade --quiet setuptools
    pip install --quiet pexpect pyserial pyyaml docutils python-dateutil
    info_msg "Installing devlib..."
    rm -rf devlib
    git clone "${DEVLIB_REPO}" devlib
    (
    cd devlib
    git checkout "${DEVLIB_TAG}"
    )
    pip2 install --quiet ./devlib
    info_msg "Installing workload-automation..."
    rm -rf workload-automation
    git clone "${WA_GIT_REPO}" workload-automation
    (
    cd workload-automation
    git checkout "${WA_TAG}"
    )
    pip2 install --quiet ./workload-automation
    export PATH=$PATH:/usr/local/bin
    which wa
    mkdir -p ~/.workload_automation
    export WA_USER_DIRECTORY=~/.workload_automation
    wa --version
    wa list instruments
fi

rm -rf wa-templates
git clone "${WA_TEMPLATES_REPO}" wa-templates
(
    cd wa-templates
    git checkout "${TEMPLATES_BRANCH}"
    cp "${CONFIG}" ../config.py
    cp "${AGENDA}" ../agenda.yaml
)

# Setup root SSH login with password for test run via loopback.
sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^# *PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
grep "PermitRootLogin yes" /etc/ssh/sshd_config
echo "root:linaro123" | chpasswd
/etc/init.d/ssh restart && sleep 3

# Ensure that csv is enabled in result processors.
if ! awk '/result_processors = [[]/,/[]]/' ./config.py | grep -q 'csv'; then
    sed -i "s/result_processors = [[]/result_processors = [\n    'csv',/" ./config.py
fi

info_msg "About to run WA with ${AGENDA}..."
wa run ./agenda.yaml -v -f -d "${OUTPUT}/wa" -c ./config.py || report_fail "wa-test-run"

# Save results from results.csv to result.txt.
# Use id-iteration_metric as test case name.
awk -F',' 'NR>1 {gsub(/[ _]/,"-",$4); printf("%s-itr%s_%s pass %s %s\n",$1,$3,$4,$5,$6)}' "${OUTPUT}/wa/results.csv" \
    | sed 's/\r//g' \
    | tee -a "${RESULT_FILE}"
