#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2024 Linaro Ltd.
set -x
. ../../lib/sh-test-lib

# source the secrets file to get the gitlab_token env var
. ../../../../../../secrets > /dev/null 2>&1

# temp hack for aarch64 geckodriver
ARCH=$(uname -m)

if [ "$ARCH" = "x86_64" ]; then
    DRIVER="geckodriver-v0.36.0-linux64.tar.gz"
    # install spire package
    wget https://github.com/Linaro/SPIRE-CLI-S-/releases/download/0.2.0-alpha%2B006/staging-spire_0.2.0-alpha+006_linux_amd64.deb
    dpkg -i staging-spire_0.2.0-alpha+006_linux_amd64.deb

elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    DRIVER="geckodriver-v0.36.0-linux-aarch64.tar.gz"
    # install spire package
    wget https://github.com/Linaro/SPIRE-CLI-S-/releases/download/0.2.0-alpha%2B019/staging-spire_0.2.0-alpha+019_linux_arm64.deb
    dpkg -i staging-spire_0.2.0-alpha+019_linux_arm64.deb

else
    echo "Unknown architecture: $ARCH"
    exit 1
fi

# Download and install gecko driver
curl -LO "https://github.com/mozilla/geckodriver/releases/download/v0.36.0/$DRIVER"
tar -xvf $DRIVER
mv geckodriver /usr/local/bin
chown root:root /usr/local/bin/geckodriver


# clone baklava-integration repo and install required pip pkgs
get_test_program "https://gitlab-ci-token:${GITLAB_TOKEN}@gitlab.com/LinaroLtd/lava/appliance/baklava-integration.git" "baklava-integration" "main"

git checkout $BRANCH_NAME

python3 -m venv venv
. venv/bin/activate
pip3 install -r requirements.txt

export SPIRE_PAT_TOKEN LAVA_TOKEN LAVA_PASSWORD SSH_KEY SSH_USERNAME SSH_SERVER SQUAD_UPLOAD_URL SQUAD_ARCHIVE_SUBMIT_TOKEN

# run tests
robot --pythonpath . --exclude gitlab_pipeline --variable remote:"$IS_REMOTE" --outputdir=.. test/

cd ..
../../utils/upload-to-squad.sh -a output.xml -u $SQUAD_UPLOAD_URL
../../utils/parse-robot-framework.py -r output.xml

exit 0
