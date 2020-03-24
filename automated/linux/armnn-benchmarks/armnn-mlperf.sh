#!/bin/sh

. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"

usage() {
    echo "Usage: $0 [-s <true|false>]" 1>&2
    exit 1
}

while getopts "s:l:m:a:b:c:d:e:f:" o; do
  case "$o" in
    s) SKIP_INSTALL="${OPTARG}" ;;
    l) LINK_SNAPSHOT="${OPTARG}" ;;
    m) MLPERF="${OPTARG}" ;;
    a) DATASET0="${OPTARG}" ;;
    b) DATASET1="${OPTARG}" ;;
    c) DATASET2="${OPTARG}" ;;
    d) DATASET3="${OPTARG}" ;;
    e) DATASET4="${OPTARG}" ;;
    f) DATASET5="${OPTARG}" ;;
    *) usage ;;
  esac
done

! check_root && error_msg "You need to be root to run this script."
create_out_dir "${OUTPUT}"

apt-get update
pkgs="ntp git wget curl libz-dev gcc g++ autoconf autogen libtool python3 python3-pip libjpeg-dev libtinfo5 libncurses5-dev libncursesw5-dev libboost-all-dev"
dhclient
install_deps "${pkgs}" "${SKIP_INSTALL}"
wget "${LINK_SNAPSHOT}"
tar xf armnn.tar.xz
cd home/buildslave/workspace/armnn-ci-build || exit
BASEDIR="$(pwd)"
export BASEDIR
cd "${BASEDIR}"/armnn/build || exit
ln -s "${BASEDIR}"/protobuf-host/lib/libprotobuf.so.15.0.0 ./libprotobuf.so.15
LD_LIBRARY_PATH="$(pwd)"
export LD_LIBRARY_PATH
chmod a+x UnitTests
./UnitTests
python3 -m pip install numpy ck
ck pull repo:ck-env
PYTHON_PATH="$(which python3)"
ck detect soft:compiler.python --full_path="${PYTHON_PATH}"
ck install package --tags=lib,python-package,numpy
echo 0 | ck install package --tags=compiler,lang-cpp
ck pull repo --url="${MLPERF}"
ck pull all
ck install package:lib-tflite-prebuilt-0.1.7-linux-aarch64
echo "default" | ck detect soft:lib.armnn --full_path="${BASEDIR}"/armnn/build/libarmnn.so --extra_tags=tflite,opencl,armnn,custom
ck pull repo:ck-mlperf
ck install package:imagenet-2012-val-min
ck install package:3013bdc96184bf3b
ck install package:a6a4613ba6dfd570
cd "${BASEDIR}" && wget "${DATASET0}"
cd "${BASEDIR}" && wget "${DATASET1}"
cd "${BASEDIR}" && wget "${DATASET2}"
cd "${BASEDIR}" && wget "${DATASET3}"
cd "${BASEDIR}" && wget "${DATASET4}"
cd "${BASEDIR}" && wget "${DATASET5}"

tar xvf dataset-imagenet-preprocessed-using-pillow.0.tar
tar xvf dataset-imagenet-preprocessed-using-pillow.1.tar
tar xvf dataset-imagenet-preprocessed-using-pillow.2.tar
tar xvf dataset-imagenet-preprocessed-using-pillow.3.tar
tar xvf dataset-imagenet-preprocessed-using-pillow.4.tar
tar xvf dataset-imagenet-preprocessed-using-pillow.5.tar

# shellcheck disable=SC2039
echo "default" | ck detect soft --tags=dataset,imagenet,preprocessed,rgb8 --extra_tags=using-opencv,custom --full_path="${BASEDIR}"/home/theodore/CK-TOOLS/dataset-imagenet-preprocessed-using-pillow/ILSVRC2012_val_00000001.rgb8
ck search env --tags=dataset,imagenet,rgb8,custom > images.txt
IMAGES=$(grep "local:env:" images.txt | sed 's/^.*://')
ck search env --tags=tflite,opencl,armnn,custom > library.txt
LIBRARY=$(grep "local:env:" library.txt | sed 's/^.*://')
ck search env --tags=compiler,lang-cpp > compiler.txt
COMPILER=$(grep "local:env:" compiler.txt | sed 's/^.*://')
# shellcheck disable=SC2039
echo "-1" | ck benchmark program:image-classification-armnn-tflite --repetitions=1 --env.CK_BATCH_SIZE=1 --env.CK_BATCH_COUNT=500 --record --record_repo=local --record_uoa=mlperf-mobilenet-armnn-tflite-accuracy-500 --tags=image-classification,mlperf,mobilenet,armnn-tflite,accuracy,500 --skip_print_timers --skip_stat_analysis --process_multi_keys --deps.compiler="${COMPILER}" --deps.library="${LIBRARY}" --deps.images="${IMAGES}"
