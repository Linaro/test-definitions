#!/bin/sh -eu

REPO_PATH="$(pwd)"
export REPO_PATH
echo "REPO_PATH: ${REPO_PATH}"

if ! [ -d "${REPO_PATH}/automated/bin" ]; then
    echo "ERROR: Please execute the below command from test-definitions DIR"
    echo "    . ./automated/bin/setenv.sh"
    exit 1
fi

PATH="${REPO_PATH}/automated/bin:${PATH}"
export PATH
echo "BIN_PATH: ${PATH}"

# Install required modules for test-runner.
. "${REPO_PATH}/automated/lib/sh-test-lib"
! check_root && error_msg "Please run this script as root"
info_msg "Checking if python-pip installed..."
! command -v pip && install_deps "python-pip"
info_msg "Installing required python modules for test-runner..."
pip install -r "${REPO_PATH}/automated/utils/requirements.txt"
