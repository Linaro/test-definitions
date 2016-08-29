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

# Install test-runner deps.
. "${REPO_PATH}"/automated/lib/sh-test-lib
info_msg "Checking if python-pip installed..."
! command -v pip && install_deps "python-pip"

info_msg "Checking if pexpect and pyyaml module installed..."
for pkg in pexpect pyyaml; do
    if ! pip list | grep -i "${pkg}"; then
        info_msg "Installing ${pkg}"
        pip install "${pkg}"
    fi
done
