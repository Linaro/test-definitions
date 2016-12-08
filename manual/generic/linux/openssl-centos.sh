#!/bin/sh

# you should NOT be root
# run following steps on CentOS as user
sudo yum -y update
# build dependencies
sudo yum -y install autoconf automake binutils bison flex gcc gcc-c++ gettext \
                 libtool sed make patch pkgconfig redhat-rpm-config rpm-build \
                 diffutils coreutils glibc-static yum-utils

# sslverify=0 to be enabled in all repo files
# to work with yumdownloader --source
REPO_FILES="/etc/yum.repos.d/"
# shellcheck disable=SC2044
for FILE in $(find "${REPO_FILES}"); do
    sudo sed -i -e 's/sslverify=1/sslverify=0/g' "${FILE}"
done
sudo yum -y clean all

# install openssl dependencies
sudo yum -y install perl openssl-devel krb5-devel zlib-devel

mkdir -p "${HOME}"/rpmbuild/BUILD
mkdir -p "${HOME}"/rpmbuild/RPMS
mkdir -p "${HOME}"/rpmbuild/SOURCES
mkdir -p "${HOME}"/rpmbuild/SPECS
mkdir -p "${HOME}"/rpmbuild/SRPMS

echo "%_topdir %(echo $HOME)/rpmbuild" > ~/.rpmmacros

# shellcheck disable=SC2164
cd "${HOME}"
# build and install lksctp-tools
sudo yumdownloader --source lksctp-tools

# get version and release of lksctp-tools
SCTP_VERSION=$(sudo yum info lksctp-tools | grep Version | head -1| awk '{print $3}')
SCTP_RELEASE=$(sudo yum info lksctp-tools | grep Release | head -1| awk '{print $3}')

rpmbuild --recompile lksctp-tools-"${SCTP_VERSION}""-""${SCTP_RELEASE}".src.rpm
# shellcheck disable=SC2164
cd "${HOME}""/rpmbuild/BUILD/lksctp-tools-""${SCTP_VERSION}"/
sudo make install

# shellcheck disable=SC2164
cd "${HOME}"
sudo yumdownloader --source openssl

# get version and release of openssl
SSL_VERSION=$(sudo yum info openssl | grep Version | awk '{print $3}')
SSL_RELEASE=$(sudo yum info openssl | grep Release | awk '{print $3}')
# run below step, you could see list of dependencies not met and exit
rpmbuild --rebuild openssl-"${SSL_VERSION}""-""${SSL_RELEASE}".src.rpm

# shellcheck disable=SC2164
cd "${HOME}"/rpmbuild/SPECS/

sed -i -e 's/BuildRequires: lksctp-tools-devel/# BuildRequires: lksctp-tools-devel/g' openssl.spec
# build will start from this command
rpmbuild -ba openssl.spec

# shellcheck disable=SC2164
cd "${HOME}""/rpmbuild/BUILD/openssl-""${SSL_VERSION}"/
make
sudo make install
make tests
