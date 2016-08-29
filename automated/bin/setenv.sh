#!/bin/sh -eu

REPO_PATH="$(pwd)"
export REPO_PATH
echo "REPO_PATH: ${REPO_PATH}"

if ! [ -d "${REPO_PATH}/automated/bin" ]; then
    echo "ERROR: Please execute the below command from 'test-definitions' DIR"
    echo "    . ./automated/bin/setenv.sh"
    exit 1
fi

PATH="${REPO_PATH}/automated/bin:${PATH}"
export PATH
echo "BIN_PATH: ${PATH}"
