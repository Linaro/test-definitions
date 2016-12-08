#!/bin/sh

# you should NOT be root - run following steps on CentOS as user
[ "$(whoami)" = "root" ] || { echo "E: You must be root" && exit 1; }

# sslverify=0 to be enabled in all repo files
# to work with yumdownloader --source
REPO_FILES="/etc/yum.repos.d/"
# shellcheck disable=SC2044
for FILE in $(find "${REPO_FILES}"); do
    sudo sed -i -e 's/sslverify=1/sslverify=0/g' "${FILE}"
done

# shellcheck disable=SC2164
cd "${HOME}"

sudo yum clean all
sudo yum update -y
sudo yum install -y gcc make rpm-build yum-utils
sudo yumdownloader --source openssl
sudo yum-builddep -y openssl
# no need to run tests as it's part of openssl package rebuild
sudo rpmbuild --rebuild openssl-*.src.rpm
