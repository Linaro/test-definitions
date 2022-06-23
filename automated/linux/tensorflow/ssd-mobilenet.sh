#!/bin/bash
# shellcheck disable=SC1091

. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
source ./tensorflow-utils.sh

HOME_DIR='/home/debiand05'
TEST_GIT_URL="https://github.com/mlcommons/inference.git"
TEST_DIR="${HOME_DIR}/${TEST_PROGRAM}"
TEST_PROG_VERSION="215c057fc6690a47f3f66c72c076a8f73d66cb12"
TEST_PROGRAM="inference"
MNT_DIR='/mnt'
MNT_EXISTS=true

usage() {
    echo "Usage: $0 [-a <home-directory>]
                    [-m <mount-directory>]
                    [-t <true|false>]
                    [-p <test-dir>]
                    [-v <test-prog-version>]
                    [-u <test-git-url>]
                    [-s <true|false>]" 1>&2
    exit 1
}

while getopts "a:m:t:s:p:v:u:" o; do
    case "$o" in
        a) export HOME_DIR="${OPTARG}";;
        m) MNT_DIR="${OPTARG}" ;;
        t) MNT_EXISTS="${OPTARG}" ;;
        s) SKIP_INSTALL="${OPTARG}" ;;
        p) export TEST_DIR="${OPTARG}" ;;
        v) export TEST_PROG_VERSION="${OPTARG}" ;;
        u) export TEST_GIT_URL="${OPTARG}" ;;
        *) usage ;;
    esac
done

pkgs="build-essential git python3-venv python3-dev libhdf5-dev pkg-config curl"
install_deps "${pkgs}" "${SKIP_INSTALL}"
create_out_dir "${OUTPUT}"
rm -rf "${HOME_DIR}"/tf_venv
rm -rf "${HOME_DIR}"/src
rm -rf "${MNT_DIR}"/datasets
mkdir "${HOME_DIR}"/tf_venv
pushd "${HOME_DIR}"/tf_venv || exit
python3 -m venv .
source bin/activate
popd || exit

if [[ "${SKIP_INSTALL}" = *alse ]]; then
    export CFLAGS="-std=c++14 -Wp,-U_GLIBCXX_ASSERTIONS"
    tensorflow_pip_install
    unset CFLAGS
    if [[ "${MNT_EXISTS}" = *alse ]]; then
        get_dataset_ssd_mobilenet
    fi
fi

pushd "${HOME_DIR}"/src/inference/vision/classification_and_detection || exit
python setup.py develop

if [[ "${MNT_EXISTS}" = *rue ]]; then
    mkdir "${MNT_DIR}"/datasets
    mount -t nfs 10.40.96.10:/mnt/nvme "${MNT_DIR}"/datasets
    export DATA_DIR="${MNT_DIR}"/datasets/data/CK-TOOLS/dataset-coco-2017-val
    export MODEL_DIR="${MNT_DIR}"/datasets/data/models
fi

./run_local.sh tf ssd-mobilenet
popd || exit