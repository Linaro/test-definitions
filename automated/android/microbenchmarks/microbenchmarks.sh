#!/bin/sh -x
# shellcheck source=/<job-id>-0/secrets
export SOURCE_PROJECT_NAME
export SOURCE_BUILD_NUMBER
export SOURCE_BUILD_URL
export SOURCE_BRANCH_NAME
export SOURCE_GERRIT_CHANGE_NUMBER
export SOURCE_GERRIT_PATCHSET_NUMBER
export SOURCE_GERRIT_CHANGE_URL
export SOURCE_GERRIT_CHANGE_ID
export ART_URL

set +x
lava_test_dir="$(find /lava-* -maxdepth 0 -type d -regex '/lava-[0-9]+' 2>/dev/null | sort | tail -1)"
if test -f "${lava_test_dir}/secrets" && grep -q "ART_TOKEN" "${lava_test_dir}/secrets"; then
        # shellcheck disable=SC1090
        . "${lava_test_dir}/secrets"
        export ART_TOKEN
        export ARTIFACTORIAL_TOKEN
fi
set -x

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
# shellcheck disable=SC1091
. ../../lib/android-test-lib

PKG_DEPS="git wget binutils curl bc xz-utils python python3 python3-scipy openjdk-8-jdk"

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
    install_latest_adb
fi

mkdir workspace
cd workspace || exit
wget  -q "${SNAPSHOTS_URL}"/"${BUILD_TARBALL}"
[ -z "$HOME" ] && export HOME="/"
git config --global user.email "ci_notify@linaro.org"
git config --global user.name "Linaro CI"
git config --global --add color.ui auto
tar -xf "${BUILD_TARBALL}"
export PATH=${PWD}/out/host/linux-x86/bin/:${PATH}

# FIXME removing latest adb from build since it is not working well from container
rm -rf "${PWD}"/out/host/linux-x86/bin/adb
initialize_adb
adb_root
curl https://storage.googleapis.com/git-repo-downloads/repo > "${PWD}"/out/host/linux-x86/bin/repo
chmod a+x "${PWD}"/out/host/linux-x86/bin/repo
repo init -q -u https://android.googlesource.com/platform/manifest
cp ../manifest.xml  .repo/manifest.xml
repo sync -j16 -c -q --no-tags
which lava-test-case && lava-test-case "test-progress" --result pass
sed -i "s| /data/local/tmp/system| /data/local/tmp/system > /dev/null|g" scripts/benchmarks/benchmarks_run_target.sh
sed -i "s| /data/art-test| /data/art-test > /dev/null|g" scripts/benchmarks/benchmarks_run_target.sh
sed -i "s|mode \"\$1\"|mode \"\$1\" --noverbose|g" scripts/benchmarks/benchmarks_run_target.sh
export OUT=${PWD}/out/target/product/${LUNCH_TARGET}/
./scripts/benchmarks/benchmarks_run_target.sh  --skip-build true --iterations "${ITERATIONS}" --mode "${MODE}"

if [ ! -z "${ART_TOKEN}" ]; then
    git clone https://git.linaro.org/people/vishal.bhoj/pbr.git; mkdir -p pbr/artifacts/
    cp ./*.json pbr/artifacts/
    wget "${SNAPSHOTS_URL}"/pinned-manifest.xml -O pbr/artifacts/pinned-manifest.xml
    cd pbr || exit
    python post-build-report.py
    tar -cJf artifacts.txz artifacts/
fi
