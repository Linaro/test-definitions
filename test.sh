#!/bin/sh

set -e

if [ -z "$1" ] || [ ! -e "test/Dockerfile.${1}" ]; then
    echo "USAGE: $0 [debian|centos]"
    exit 1
fi

python3 validate.py -g -s SC1091
docker build -f test/Dockerfile."${1}" -t erp-"${1}" . && docker run --rm -it -v "$(pwd)":/work erp-"${1}"

