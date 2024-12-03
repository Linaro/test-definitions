#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2024 Linaro Ltd.
set -x
. ../../lib/sh-test-lib

# source the secrets file to get the gitlab_token env var
. ../../../../../../secrets > /dev/null 2>&1

# install dependencies
install_deps "bzip2 curl firefox-esr git python3-pip wget" "$SKIP_INSTALL"

# install spire package
wget https://github.com/Linaro/SPIRE-CLI-S-/releases/download/0.2.0-alpha%2B006/staging-spire_0.2.0-alpha+006_linux_amd64.deb
dpkg -i staging-spire_0.2.0-alpha+006_linux_amd64.deb

# clone baklava-integration repo and install required pip pkgs
get_test_program "https://gitlab-ci-token:${GITLAB_TOKEN}@gitlab.com/LinaroLtd/lava/appliance/baklava-integration.git" "baklava-integration" "main"

pip3 install -r requirements.txt

export SPIRE_PAT_TOKEN LAVA_TOKEN LAVA_PASSWORD

# run tests
robot --pythonpath . --variable remote:"$IS_REMOTE" --outputdir=.. test/
exit 0
