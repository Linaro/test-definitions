#!/bin/sh -e
# shellcheck disable=SC1090

TEST_DIR=$(dirname "$(realpath "$0")")
OUTPUT="${TEST_DIR}/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE
SKIP_INSTALL="false"
export SKIP_INSTALL
ANDROID_SERIAL=""
BOOT_TIMEOUT="300"

WA_TEMPLATES_REPO="https://git.linaro.org/people/chase.qi/wa-templates.git"
CONFIG="config/generic-android.py"
AGENDA="agenda/generic-linpack.yaml"
BUILD_TOOLS_URL="http://testdata.validation.linaro.org/apks/workload-automation/build-tools.tar.gz"
WA_HOME_URL="http://testdata.validation.linaro.org/apks/workload-automation/workload_automation_home.tar.gz"

usage() {
    echo "Usage: $0 [-S <true|false>] [-s <android_serial>] [-t <boot_timeout>] [-r <wa_templates_repo>] [-c <config>] ['-a <agenda>'] ['-b <build_tools_url>'] ['-w <wa_home_url>']" 1>&2
    exit 1
}

while getopts ":S:s:t:w:r:c:a:b:w:" opt; do
    case "${opt}" in
        S) SKIP_INSTALL="${OPTARG}" ;;
        s) ANDROID_SERIAL="${OPTARG}" ;;
        t) BOOT_TIMEOUT="${OPTARG}" ;;
        w) WA_HOME_URL="${OPTARG}" ;;
        r) WA_TEMPLATES_REPO="${OPTARG}" ;;
        c) CONFIG="${OPTARG}" ;;
        a) AGENDA="${OPTARG}" ;;
        b) BUILD_TOOLS_URL="${OPTARG}" ;;
        w) WA_HOME_URL="${OPTARG}" ;;
        *) usage ;;
    esac
done

. "${TEST_DIR}/../lib/sh-test-lib"
. "${TEST_DIR}/../lib/android-test-lib"

! check_root && error_msg "Please run this test as root."
cd "${TEST_DIR}"
create_out_dir "${OUTPUT}"

if [ "${SKIP_INSTALL}" = "true" ] || [ "${SKIP_INSTALL}" = "True" ]; then
    info_msg "WA installation skipped"
else
    PKGS="git wget zip tar xz-utils python python-yaml python-lxml python-setuptools python-numpy python-colorama python-pip sqlite3 libstdc++6:i386 libgcc1:i386 zlib1g:i386 libncurses5:i386 aapt android-tools-adb android-tools-fastboot time sysstat openssh-client openssh-server sshpass python-jinja2 curl"
    dpkg --add-architecture i386
    install_deps "${PKGS}"
    pip install --upgrade pip && hash -r
    pip install --upgrade setuptools
    pip install pexpect pyserial pyyaml docutils python-dateutil
    info_msg "Installing workload-automation..."
    rm -rf workload-automation
    git clone https://github.com/ARM-software/workload-automation
    pip install ./workload-automation
    export PATH=$PATH:/usr/local/bin
    which wa

    info_msg "Installing SDK build-tools..."
    (
        cd /usr/
        # Copy build-tools.tar.gz to /usr for local run.
        test -f build-tools.tar.gz || wget -S --progress=dot:giga "${BUILD_TOOLS_URL}"
        tar -xf build-tools.tar.gz
    )

    info_msg "Installing workloads bbench and APKs..."
    (
        cd /root/
        # Copy workload_automation_home.tar.gz to /root for local run.
        test -f workload_automation_home.tar.gz || wget -S --progress=dot:giga "${WA_HOME_URL}"
        tar -xf workload_automation_home.tar.gz
    )
fi

initialize_adb
adb_root
wait_boot_completed "${BOOT_TIMEOUT}"
disable_suspend

rm -rf wa-templates
git clone "${WA_TEMPLATES_REPO}" wa-templates
(
    cd wa-templates
    cp "${CONFIG}" ../config.py
    cp "${AGENDA}" ../agenda.yaml
)

sed -i "s/adb_name=.*/adb_name=\'${ANDROID_SERIAL}\',/" ./config.py
# Ensure that sqlite is enabled in result processors.
if ! awk '/result_processors = [[]/,/[]]/' ./config.py | grep -q 'sqlite'; then
    awk '/result_processors = [[]/,/[]]/' ./config.py \
        | sed -i "s/result_processors = [[]/result_processors = [\n    'sqlite',/"
fi

info_msg "device-${ANDROID_SERIAL}: About to run WA with ${AGENDA}..."
wa run ./agenda.yaml -v -f -d "${OUTPUT}/wa" -c ./config.py
