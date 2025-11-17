#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2024 Linaro Ltd.
set -x
. ../../lib/sh-test-lib

UTILS_PATH=$(cd ../../utils && pwd)

# source the secrets file to get the gitlab_token env var
lava_test_dir="$(
  dir="$(pwd)"
  while [ "$dir" != "/" ]; do
    find "$dir" -maxdepth 1 -type d -regex '.*/lava-[0-9]+' 2>/dev/null
    dir=$(dirname "$dir")
  done |
  sort -t- -k2,2n |
  tail -1
)"
if test -f "${lava_test_dir}/secrets"; then
. "${lava_test_dir}/secrets"
fi

# Determine the appropriate packages for the architecture
SPIRE_VERSION="0.3.4"
GECKO_VERSION="v0.36.0"
UV_VERSION="0.9.4"

detect_abi
# shellcheck disable=SC2154
case "${abi}" in
  x86_64)
    GECKODRIVER_ARCH="linux64"
    SPIRE_ARCH="linux_amd64"
    ;;
  arm64|aarch64)
    GECKODRIVER="linux-aarch64"
    SPIRE_ARCH="linux_arm64"
    ;;
  *)
    echo "Unknown architecture: ${abi}"
    exit 1
    ;;
esac

GECKODRIVER="geckodriver-${GECKO_VERSION}-${GECKODRIVER_ARCH}.tar.gz"
SPIRE="staging-spire_${SPIRE_VERSION}_${SPIRE_ARCH}.deb"

# Download and install spire package
curl -sSLO "https://github.com/Linaro/SPIRE-CLI-S-/releases/download/$SPIRE_VERSION/$SPIRE"
dpkg -i "$SPIRE"

# Download and install gecko driver
curl -LO "https://github.com/mozilla/geckodriver/releases/download/${GECKO_VERSION}/$GECKODRIVER"
tar -xf "$GECKODRIVER"
mv geckodriver /usr/local/bin
chown root:root /usr/local/bin/geckodriver

# Download and install uv
curl -LsSf "https://astral.sh/uv/${UV_VERSION}/install.sh" | sh
. "$HOME"/.local/bin/env

# clone baklava-integration repo and install required pip pkgs
get_test_program "https://gitlab-ci-token:${GITLAB_TOKEN}@gitlab.com/LinaroLtd/lava/appliance/baklava-integration/docker-tests.git" "docker-tests" "$BRANCH_NAME"

export SPIRE_PAT_TOKEN LAVA_TOKEN LAVA_PASSWORD SQUAD_UPLOAD_URL SQUAD_ARCHIVE_SUBMIT_TOKEN

# run tests with uv
uv run robot --pythonpath . --exclude gitlab_pipeline --variable remote:"$IS_REMOTE" --outputdir=.. --listener test/keyword_listener.py test/

"${UTILS_PATH}"/upload-to-squad.sh -a ../output.xml -u "$SQUAD_UPLOAD_URL"
uv run --project "${UTILS_PATH}"/ uv run "${UTILS_PATH}"/parse-robot-framework.py -r ../output.xml

exit 0
