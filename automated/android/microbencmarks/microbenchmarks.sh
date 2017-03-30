lava-lxc-device-add
apt-get update
apt-get install -y -f git wget xz-utils python python-scipy binutils curl bc
apt-get install -y -f xz-utils python3 python3-scipy binutils curl bc openjdk-8-jdk
mkdir workspace
cd workspace
wget  -q ${SNAPSHOTS_URL}/${BUILD_TARBALL}
export HOME=$PWD
git config --global user.email "ci_notify@linaro.org"
git config --global user.name "Linaro CI"
tar -xvf ${BUILD_TARBALL}
export PATH=$PWD/out/host/linux-x86/bin/:$PATH
adb start-server
adb devices
adb root
lava-lxc-device-add
curl https://storage.googleapis.com/git-repo-downloads/repo > $PWD/out/host/linux-x86/bin/repo
chmod a+x $PWD/out/host/linux-x86/bin/repo
repo init -u https://android.googlesource.com/platform/manifest
cp ../manifest.xml -O .repo/manifest.xml
repo sync -j16 -c
adb devices
export OUT=${PWD}/out/target/product/${LUNCH_TARGET}/
./scripts/benchmarks/benchmarks_run_target.sh  --skip-build true --iterations ${ITERATIONS} --mode ${MODE}
git clone https://git.linaro.org/people/vishal.bhoj/pbr.git; mkdir -p pbr/artifacts/
cp *.json pbr/artifacts/
wget ${SNAPSHOTS_URL}/pinned-manifest.xml -O pbr/artifacts/pinned-manifest.xml
cd pbr
python post-build-report.py
