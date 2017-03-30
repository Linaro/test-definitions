#!/bin/sh -x
source ${SECRETS_FILE}
export SOURCE_PROJECT_NAME
export SOURCE_BUILD_NUMBER
export SOURCE_BUILD_URL
export ART_URL

set +x
export ART_TOKEN
set -x

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
# shellcheck disable=SC1091
. ../../lib/android-test-lib

PKG_DEPS="git wget binutils curl bc xz-utils python python3 python3-scipy openjdk-8-jdk gnupg"
install_deps "${PKG_DEPS}" "${SKIP_INSTALL}"

SKIP_INSTALL="false"

usage() {
    echo "Usage: $0 [-s <true|false>]" 1>&2
    exit 1
}

while getopts ':s' opt; do
    case "${opt}" in
        s) SKIP_INSTALL="${OPTARG}" ;;
        *) usage ;;
    esac
done

if [ "${SKIP_INSTALL}" = "true" ] || [ "${SKIP_INSTALL}" = "True" ]; then
    info_msg "Package installation skipped"
else
    install_deps "${PKG_DEPS}"
fi

mkdir workspace
cd workspace || exit
wget  -q "${SNAPSHOTS_URL}"/"${BUILD_TARBALL}"
export HOME=${PWD}
git config --global user.email "ci_notify@linaro.org"
git config --global user.name "Linaro CI"
tar -xvf "${BUILD_TARBALL}"
export PATH=${PWD}/out/host/linux-x86/bin/:${PATH}
wget http://people.linaro.org/~vishal.bhoj/adb -O ${PWD}/out/host/linux-x86/bin/adb
chmod a+x ${PWD}/out/host/linux-x86/bin/adb
initialize_adb
adb_root
curl https://storage.googleapis.com/git-repo-downloads/repo > "${PWD}"/out/host/linux-x86/bin/repo
chmod a+x "${PWD}"/out/host/linux-x86/bin/repo
repo init -u https://android.googlesource.com/platform/manifest
cp ../manifest.xml  .repo/manifest.xml
repo sync -j16 -c
export OUT=${PWD}/out/target/product/${LUNCH_TARGET}/
./scripts/benchmarks/benchmarks_run_target.sh  --skip-build true --iterations "${ITERATIONS}" --mode "${MODE}"
git clone https://git.linaro.org/people/vishal.bhoj/pbr.git; mkdir -p pbr/artifacts/
cp ./*.json pbr/artifacts/
wget "${SNAPSHOTS_URL}"/pinned-manifest.xml -O pbr/artifacts/pinned-manifest.xml
cd pbr || exit
python post-build-report.py
