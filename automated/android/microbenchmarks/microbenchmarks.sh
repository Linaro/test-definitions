#!/bin/sh -x
export SOURCE_PROJECT_NAME=${SOURCE_PROJECT_NAME}
export SOURCE_BUILD_NUMBER=${SOURCE_BUILD_NUMBER}
export SOURCE_BUILD_URL=${SOURCE_BUILD_URL}
export ART_TOKEN=${ART_TOKEN}
export ART_URL=${ART_URL}

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
# shellcheck disable=SC1091
. ../../lib/android-test-lib

PKG_DEPS="git wget binutils curl bc xz-utils python python3 python3-scipy openjdk-8-jdk"
install_deps "${PKG_DEPS}"
mkdir workspace
cd workspace || exit
wget  -q "${SNAPSHOTS_URL}"/"${BUILD_TARBALL}"
export HOME=${PWD}
git config --global user.email "ci_notify@linaro.org"
git config --global user.name "Linaro CI"
tar -xvf "${BUILD_TARBALL}"
export PATH=${PWD}/out/host/linux-x86/bin/:${PATH}
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
