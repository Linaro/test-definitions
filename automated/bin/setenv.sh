#!/bin/sh

export REPO_PATH="$(pwd)"
echo "REPO_PATH: ${REPO_PATH}"

if ! [ -d "${REPO_PATH}/automated/bin" ]; then
    echo "ERROR: Please execute the below command from test-definitions DIR"
    echo "    . ./automated/bin/setenv.sh"
    exit 1
fi

export PATH="${REPO_PATH}/automated/bin":"${PATH}"
echo "BIN_PATH: ${PATH}"
