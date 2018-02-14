#!/bin/sh -ex
# shellcheck disable=SC1090

TEST_DIR=$(dirname "$(realpath "$0")")
OUTPUT="${TEST_DIR}/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE
SKIP_INSTALL="false"
ANDROID_SERIAL=""
BOOT_TIMEOUT="300"
PROBE=""
WA_TAG="master"
WA_TEMPLATES_REPO="https://git.linaro.org/qa/wa2-lava.git"
TEMPLATES_BRANCH="wa-templates"
CONFIG="config/generic-android.py"
AGENDA="agenda/generic-linpack.yaml"
BUILD_TOOLS_URL="http://testdata.validation.linaro.org/apks/workload-automation/build-tools.tar.gz"
WA_HOME_URL="http://testdata.validation.linaro.org/apks/workload-automation/workload_automation_home.tar.gz"

usage() {
    echo "Usage: $0 [-s <true|false>] [-S <android_serial>] [-t <boot_timeout>] [-T <wa_tag>] [-r <wa_templates_repo>] [-g <templates_branch>] [-c <config>] [-a <agenda>] [-b <build_tools_url>] [-w <wa_home_url>] [-p <aep_path>]" 1>&2
    exit 1
}

while getopts ":s:S:t:T:r:g:c:a:b:w:p:" opt; do
    case "${opt}" in
        s) SKIP_INSTALL="${OPTARG}" ;;
        S) ANDROID_SERIAL="${OPTARG}" ;;
        t) BOOT_TIMEOUT="${OPTARG}" ;;
        T) WA_TAG="${OPTARG}" ;;
        r) WA_TEMPLATES_REPO="${OPTARG}" ;;
        g) TEMPLATES_BRANCH="${OPTARG}" ;;
        c) CONFIG="${OPTARG}" ;;
        a) AGENDA="${OPTARG}" ;;
        b) BUILD_TOOLS_URL="${OPTARG}" ;;
        w) WA_HOME_URL="${OPTARG}" ;;
        p) PROBE="${OPTARG}" ;;
        *) usage ;;
    esac
done

. "${TEST_DIR}/../../lib/sh-test-lib"
. "${TEST_DIR}/../../lib/android-test-lib"

cd "${TEST_DIR}"
create_out_dir "${OUTPUT}"

if [ "${SKIP_INSTALL}" = "true" ] || [ "${SKIP_INSTALL}" = "True" ]; then
    info_msg "WA installation skipped"
else
    PKGS="git wget zip tar xz-utils python python-yaml python-lxml python-setuptools python-numpy python-colorama python-pip sqlite3 lib32stdc++6 lib32z1 lib32gcc1 lib32ncurses5 aapt android-tools-adb time sysstat python-jinja2 curl"
    ! check_root && error_msg "Please run this test as root."
    dpkg --add-architecture i386
    install_deps "${PKGS}"
    pip install --upgrade pip && hash -r
    pip install --upgrade setuptools
    pip install pexpect pyserial pyyaml docutils python-dateutil
    info_msg "Installing workload-automation..."
    rm -rf workload-automation
    git clone https://github.com/ARM-software/workload-automation
    (
    cd workload-automation
    git checkout -b test-branch "${WA_TAG}"
    )
    pip2 install ./workload-automation
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
    wa --version
    wa list instruments
fi

initialize_adb
adb_root
wait_boot_completed "${BOOT_TIMEOUT}"
disable_suspend

rm -rf wa-templates
git clone "${WA_TEMPLATES_REPO}" wa-templates
(
    cd wa-templates
    git checkout "${TEMPLATES_BRANCH}"
    cp "${CONFIG}" ../config.py
    cp "${AGENDA}" ../agenda.yaml
)

sed -i "s/adb_name=.*/adb_name=\'${ANDROID_SERIAL}\',/" ./config.py
# Ensure that csv is enabled in result processors.
if ! awk '/result_processors = [[]/,/[]]/' ./config.py | grep -q 'csv'; then
    sed -i "s/result_processors = [[]/result_processors = [\n    'csv',/" ./config.py
fi

if [ -z "${PROBE}" ]; then
    # LAVA supports one probe per device for now.
    PROBE=$(find /dev/serial/by-id/ -name "usb-NXP_SEMICOND_ARM_Energy_Probe*" | head -n 1)
fi

# If AEP exists, find the correct AEP config file and update the AEP config path in the agenda.
if [ -n "${PROBE}" ]; then
(
    cd "${WA_EXTENSION_PATHS}"
    # find config file with matching probe ID
    CONFIG_FILE=$(basename "$(grep -rl "${PROBE}" .)")
    cd -
    # update AEP config path on agenda
    sed -i "s|\$WA_EXTENSION_PATHS/*.*|\$WA_EXTENSION_PATHS/'${CONFIG_FILE}'\"|" agenda.yaml
)
fi

info_msg "device-${ANDROID_SERIAL}: About to run WA with ${AGENDA}..."
wa run ./agenda.yaml -v -f -d "${OUTPUT}/wa" -c ./config.py || report_fail "wa-test-run"

# Generate result.txt for sending results to LAVA.
# Use id-iteration_metric as test case name.
awk -F',' 'NR>1 {gsub(/[ _]/,"-",$4); printf("%s-itr%s_%s pass %s %s\n",$1,$3,$4,$5,$6)}' "${OUTPUT}/wa/results.csv" \
    | sed 's/\r//g' \
    | tee -a "${RESULT_FILE}"
