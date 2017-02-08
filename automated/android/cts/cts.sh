#!/bin/sh -x

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
# shellcheck disable=SC1091
. ../../lib/android-test-lib

JDK="openjdk-8-jdk-headless"
PKG_DEPS="curl wget zip xz-utils python-lxml python-setuptools python-pexpect aapt android-tools-adb lib32z1-dev libc6-dev-i386 lib32gcc1 libc6:i386 libstdc++6:i386 libgcc1:i386 zlib1g:i386 libncurses5:i386"
CTS_URL="http://testdata.validation.linaro.org/cts/android-cts-7.1_r1.zip"
TEST_PARAMS="run cts -m CtsBionicTestCases --abi arm64-v8a --disable-reboot --skip-preconditions --skip-device-info"
RESULT_FILE="$(pwd)/output/result.txt"
export RESULT_FILE

usage() {
    echo "Usage: $0 [-s <true|false>] [-n serialno] [-d jdk-version] [-c cts_url] [-t test_params]" 1>&2
    exit 1
}

while getopts ':s:n:d:c:t:' opt; do
    case "${opt}" in
        s) SKIP_INSTALL="${OPTARG}" ;;
        n) SN="${OPTARG}" ;;
        d) JDK="${OPTARG}" ;;
        c) CTS_URL="${OPTARG}" ;;
        t) TEST_PARAMS="${OPTARG}" ;;
        *) usage ;;
    esac
done

if [ "${SKIP_INSTALL}" = "true" ] || [ "${SKIP_INSTALL}" = "True" ]; then
    info_msg "Package installation skipped"
else
    dist_name
    dist_info
    # shellcheck disable=SC2154
    case "${dist}" in
        debian)
            dpkg --add-architecture i386
            dist_info
            echo "deb [arch=amd64,i386] http://ftp.us.debian.org/debian ${Codename} main non-free contrib" > /etc/apt/sources.list.d/cts.list
            echo "deb http://ftp.debian.org/debian ${Codename}-backports main" >> /etc/apt/sources.list.d/cts.list
            cat /etc/apt/sources.list.d/cts.list
            apt-get update || true
            install_deps "${JDK}" || install_deps "-t ${Codename}-backports ${JDK}"
            install_deps "${PKG_DEPS}"
            ;;
        *)
            install_deps "${PKG_DEPS} ${JDK}"
            ;;
    esac
fi

initialize_adb
wait_for_boot_completed 300

# Increase the heap size. KVM devices in LAVA default to ~250M of heap
export _JAVA_OPTIONS="-Xmx350M"
java -version

# Download CTS test package or copy it from local disk.
if echo "${CTS_URL}" | grep "^http" ; then
    wget -S --progress=dot:giga "${CTS_URL}"
else
    cp "${CTS_URL}" ./
fi
file_name=$(basename "${CTS_URL}")
unzip -q "${file_name}"
rm -f "${file_name}"

if [ -d android-cts/results ]; then
    mv android-cts/results "android-cts/results_$(date +%Y%m%d%H%M%S)"
fi

./cts-runner.py -t "${TEST_PARAMS}" -n "${SN}"
check_return "cts-test-run"
