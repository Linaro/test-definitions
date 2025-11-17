#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2024 Linaro Ltd.
set -x
. ../../lib/sh-test-lib

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
ARCH=$(uname -m)
SPIRE_VERSION="0.3.4"

if [ "$ARCH" = "x86_64" ]; then
    DRIVER="geckodriver-v0.36.0-linux64.tar.gz"
    SPIRE="staging-spire_${SPIRE_VERSION}_linux_amd64.deb"

elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    DRIVER="geckodriver-v0.36.0-linux-aarch64.tar.gz"
    SPIRE="staging-spire_${SPIRE_VERSION}_linux_arm64.deb"
else
    echo "Unknown architecture: $ARCH"
    exit 1
fi

# Download and install spire package
curl -sSLO "https://github.com/Linaro/SPIRE-CLI-S-/releases/download/$SPIRE_VERSION/$SPIRE"
dpkg -i "$SPIRE"

# Download and install gecko driver
curl -LO "https://github.com/mozilla/geckodriver/releases/download/v0.36.0/$DRIVER"
tar -xf "$DRIVER"
mv geckodriver /usr/local/bin
chown root:root /usr/local/bin/geckodriver

# Download and install uv
curl -LsSf https://astral.sh/uv/install.sh | sh
. "$HOME"/.local/bin/env

# clone baklava-integration repo and install required pip pkgs
get_test_program "https://gitlab-ci-token:${GITLAB_TOKEN}@gitlab.com/LinaroLtd/lava/appliance/baklava-integration/docker-tests.git" "docker-tests" "main"
git checkout "$BRANCH_NAME"

export SPIRE_PAT_TOKEN LAVA_TOKEN LAVA_PASSWORD SQUAD_UPLOAD_URL SQUAD_ARCHIVE_SUBMIT_TOKEN

# run tests with uv
uv run robot --pythonpath . --exclude gitlab_pipeline --variable remote:"$IS_REMOTE" --outputdir=.. --listener test/keyword_listener.py test/

../../../utils/upload-to-squad.sh -a ../output.xml -u "$SQUAD_UPLOAD_URL"
uv run --project ../../../utils/ uv run ../../../utils/parse-robot-framework.py -r ../output.xml

exit 0
