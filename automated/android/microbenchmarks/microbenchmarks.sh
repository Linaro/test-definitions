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
export QA_REPORTS_URL

set +x
lava_test_dir="$(find /lava-* -maxdepth 0 -type d -regex '/lava-[0-9]+' 2>/dev/null | sort | tail -1)"
if test -f "${lava_test_dir}/secrets"; then
        # shellcheck disable=SC1090
        . "${lava_test_dir}/secrets"
        export ARTIFACTORIAL_TOKEN
        export QA_REPORTS_TOKEN
fi
set -x

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
# shellcheck disable=SC1091
. ../../lib/android-test-lib

PKG_DEPS="git wget binutils bc xz-utils python python3 python3-scipy"

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

# Download/extract the stripped down tree.
wget  -q "${SNAPSHOTS_URL}/test-tree.txz"
tar -xf "test-tree.txz"

# Download/extract the build results.
wget  -q "${SNAPSHOTS_URL}"/"${BUILD_TARBALL}"
tar -xf "${BUILD_TARBALL}"

[ -z "$HOME" ] && export HOME="/"
export PATH="${PWD}/out/host/linux-x86/bin/:${PATH}"

# FIXME removing latest adb from build since it is not working well from container
rm -rf "${PWD}"/out/host/linux-x86/bin/adb
initialize_adb
adb_root

which lava-test-case && lava-test-case "test-progress" --result pass
sed -i "s| /data/local/tmp/system| /data/local/tmp/system > /dev/null|g" scripts/benchmarks/benchmarks_run_target.sh
sed -i "s| /data/art-test| /data/art-test > /dev/null|g" scripts/benchmarks/benchmarks_run_target.sh
sed -i "s|mode \"\$1\"|mode \"\$1\" --noverbose|g" scripts/benchmarks/benchmarks_run_target.sh
export OUT="${PWD}/out/target/product/${LUNCH_TARGET}/"
./scripts/benchmarks/benchmarks_run_target.sh  --skip-build true --iterations "${ITERATIONS}" \
  --mode "${MODE}" --target-device "${LUNCH_TARGET}"

if [ -n "${QA_REPORTS_TOKEN}" ]; then
    git clone https://git.linaro.org/qa/post-build-report.git pbr; mkdir -p pbr/artifacts/
    cp ./*.json pbr/artifacts/
    wget "${SNAPSHOTS_URL}"/pinned-manifest.xml -O pbr/artifacts/pinned-manifest.xml
    cd pbr || exit
    python post-build-report.py
    tar -cJf artifacts.txz artifacts/
fi
