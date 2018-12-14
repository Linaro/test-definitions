#!/bin/sh
set -ex

python3 validate.py \
    -g \
    -r build-error.txt \
    -p E501 \
    -s SC1091
