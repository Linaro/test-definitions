#!/bin/bash

export DATA_DIR=${HOME}/CK-TOOLS/dataset-coco-2017-val
export MODEL_DIR=${HOME}/models

#PIP install prerequisits required for running tensorflow via ck and MLPerf.
tensorflow_pip_install(){
    pushd "${HOME_DIR}"/tf_venv || exit
    python -m pip install --upgrade pip wheel
    python -m pip install h5py
    python -m pip install cython
    python -m pip install google protobuf==3.20.1
    python -m pip install --no-binary pycocotools pycocotools
    python -m pip install absl-py pillow
    python -m pip install --extra-index-url https://snapshots.linaro.org/ldcg/python-cache/ numpy==1.19.5
    python -m pip install --extra-index-url https://snapshots.linaro.org/ldcg/python-cache/ matplotlib
    python -m pip install ck
    ck pull repo:ck-env
    python -m pip install scikit-build
    python -m pip install --extra-index-url https://snapshots.linaro.org/ldcg/python-cache/ tensorflow-io-gcs-filesystem==0.24.0 h5py==3.1.0
    python -m pip install tensorflow-aarch64==2.7.0
    popd || exit
    mkdir "${HOME_DIR}"/src
    get_test_program "${TEST_GIT_URL}" "${TEST_DIR}" "${TEST_PROG_VERSION}" "${TEST_PROGRAM}"
    git submodule update --init --recursive
    pushd "${HOME_DIR}"/src/"${TEST_PROGRAM}"/loadgen || exit
    python setup.py develop
    popd || exit
}
#Setup for the ssd_mobilenet dataset if the dataset does not already exist on device
get_dataset_ssd_mobilenet(){
    mkdir models
    pushd models || exit
    ck install package --tags=object-detection,dataset,coco,val
    mobilenet="http://download.tensorflow.org/models/mobilenet_v1_2018_08_02/mobilenet_v1_1.0_224.tgz"
    curl -sSOL "${mobilenet}"
    tar -zxf "$(baseame "${mobilenet}")"
    ssd_mobilenet_coco_version="ssd_mobilenet_v1_coco_2018_01_28"
    ssd_mobilenet="http://download.tensorflow.org/models/object_detection/${ssd_mobilenet_coco_version}.tar.gz"
    curl -sSOL "${ssd_mobilenet}"
    tar -zxf "$(baseame "${ssd_mobilenet}")"
    cp "${ssd_mobilenet_coco_version}/frozen_inference_graph.pb" "${ssd_mobilenet_coco_version}.pb"
    popd  || exit
}
#Setup for the imagenet-ssd-resnet32 dataset if the dataset does not already exist on device
get_dataset_imagenet_ssd_resnet32(){
    mkdir models
    pushd models || exit
    ck install package --tags=object-detection,dataset,coco,val # Choose [0] the 2017 data
    ssd_resnet34="https://zenodo.org/record/3345892/files/tf_ssd_resnet34_22.1.zip"
    curl -sSOL "${ssd_resnet34}"
    unzip "$(baseame "${ssd_resnet34}")"
    cp tf_ssd_resnet34_22.1/resnet34_tf.22.1.pb .
    popd || exit
    pushd "${HOME_DIR}"/src/inference/vision/classification_and_detection  || exit
    python tools/ssd-nhwc.py ~/models/resnet34_tf.22.1.pb
    mv ~/models/resnet34_tf.22.1.pb.patch ~/models/resnet34_tf.22.1.pb
    popd  || exit
}
#Setup for the resnet50 dataset if the dataset does not already exist on device
get_dataset_imagenet_resnet50(){
    mkdir models
    pushd models || exit
    ck install package --tags=image-classification,dataset,imagenet,aux
    ck install package --tags=image-classification,dataset,imagenet,val
    cp "${HOME_DIR}"/CK-TOOLS/dataset-imagenet-ilsvrc2012-aux-from.dividiti/val.txt "${HOME_DIR}"/CK-TOOLS/dataset-imagenet-ilsvrc2012-val-min/val_map.txt
    resnet50="https://zenodo.org/record/2535873/files/resnet50_v1.pb"
    curl -sSOL "${resnet50}"
    export DATA_DIR=${HOME}/CK-TOOLS/dataset-imagenet-ilsvrc2012-val-min
    popd || exit
}