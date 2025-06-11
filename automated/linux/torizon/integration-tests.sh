#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2024 Linaro Ltd.
set -x
. ../../lib/sh-test-lib

# source the secrets file to get the gitlab_token env var
. ../../../../../../secrets > /dev/null 2>&1

# temp hack for aarch64 geckodriver
curl -LO "https://github.com/mozilla/geckodriver/releases/download/v0.36.0/geckodriver-v0.36.0-linux-aarch64.tar.gz"
tar -xvf geckodriver-v0.36.0-linux-aarch64.tar.gz
mv geckodriver /usr/local/bin
chown root:root /usr/local/bin/geckodriver

# install spire packages
wget https://github.com/Linaro/SPIRE-CLI-S-/releases/download/0.2.0-alpha%2B006/staging-spire_0.2.0-alpha+006_linux_amd64.deb
dpkg -i staging-spire_0.2.0-alpha+006_linux_amd64.deb
# also for arm64
wget https://github.com/Linaro/SPIRE-CLI-S-/releases/download/0.2.0-alpha%2B019/staging-spire_0.2.0-alpha+019_linux_arm64.deb
dpkg -i staging-spire_0.2.0-alpha+019_linux_arm64.deb

# clone baklava-integration repo and install required pip pkgs
get_test_program "https://gitlab-ci-token:${GITLAB_TOKEN}@gitlab.com/LinaroLtd/lava/appliance/baklava-integration.git" "baklava-integration" "main"

git checkout debug-registration

pip3 install -r requirements.txt

export SPIRE_PAT_TOKEN LAVA_TOKEN LAVA_PASSWORD

# run tests
robot --pythonpath . --variable remote:"$IS_REMOTE" --outputdir=.. test/

exit 0
