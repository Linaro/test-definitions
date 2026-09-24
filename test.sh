#!/bin/sh

set -e

if [ -z "$1" ] || [ ! -e "test/Dockerfile.${1}" ]; then
    echo "USAGE: $0 [debian|fedora]"
    exit 1
fi

./sanity-check.sh
docker build -f test/Dockerfile."${1}" -t erp-"${1}" . && docker run --rm -it -v "$(pwd)":/work erp-"${1}"

