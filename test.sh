#!/bin/sh

set -e

if [ -z "$1" ] || [ ! -e "test/Dockerfile.${1}" ]; then
    echo "USAGE: $0 [debian|centos]"
    exit 1
fi

python3 validate.py -p E501 W503 -s SC1091 SC2230
docker build -f test/Dockerfile."${1}" -t erp-"${1}" . && docker run --rm -it -v "$(pwd)":/work erp-"${1}"

