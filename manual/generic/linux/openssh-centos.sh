#!/bin/sh

OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
RESULT_LOG="${OUTPUT}/result_log.txt"
TEST_LOG="${OUTPUT}/test_log.txt"


parse_output() {
    egrep "^failed|^ok" "${TEST_LOG}" | tee -a "${RESULT_LOG}"
    sed -i -e 's/ok/pass/g' "${RESULT_LOG}"
    sed -i -e 's/failed/fail/g' "${RESULT_LOG}"
    echo "=== Openssh results summary ==="
    awk '{for (i=2; i<NF; i++) printf $i "-"; print $NF " " $1}' "${RESULT_LOG}" 2>&1 | tee -a "${RESULT_FILE}"
}

# you should NOT be root
# run following steps on CentOS as user
sudo yum -y update
# sslverify=0 to be enabled in all repo files
REPO_FILES="/etc/yum.repos.d/"
# shellcheck disable=SC2044
for FILE in $(find "${REPO_FILES}"); do
    sudo sed -i -e 's/sslverify=1/sslverify=0/g' "${FILE}"
done

sudo yum -y clean all
sudo yum -y install autoconf automake binutils bison flex gcc gcc-c++ gettext \
             libtool make patch pkgconfig redhat-rpm-config rpm-build yum-utils

sudo yumdownloader --source openssh
# currently installed openssh version rpm package
# File name could be different version
mkdir -p ~/rpmbuild/BUILD
mkdir -p ~/rpmbuild/RPMS
mkdir -p ~/rpmbuild/SOURCES
mkdir -p ~/rpmbuild/SPECS
mkdir -p ~/rpmbuild/SRPMS

echo "%_topdir %(echo $HOME)/rpmbuild" > ~/.rpmmacros
# install openssh dependencies
sudo yum -y install gtk2-devel libX11-devel openldap-devel zlib-devel \
                 audit-libs-devel groff pam-devel tcp_wrappers-devel \
                 fipscheck-devel openssl-devel krb5-devel libedit-devel \
                 ncurses-devel libselinux-devel xauth libcap-ng-devel
# you may see fipscheck-devel not found
# download fipscheck source and build it
wget https://fedorahosted.org/releases/f/i/fipscheck/fipscheck-1.4.1.tar.bz2
bunzip2 fipscheck-1.4.1.tar.bz2
tar -xvf fipscheck-1.4.1.tar
# shellcheck disable=SC2164
cd fipscheck-1.4.1/
automake
./configure --build=arm --host=arm
make
sudo make install
# go to home directory
# shellcheck disable=SC2164
cd ~/
# get version and release of openssh
VERSION=$(sudo  yum info openssh | grep Version | awk '{print $3}')
RELEASE=$(sudo  yum info openssh | grep Release | awk '{print $3}')
# run below step, you could see list of dependencies not met and exit
rpmbuild --rebuild openssh-"${VERSION}""-""${RELEASE}".src.rpm
# shellcheck disable=SC2164
cd ~/rpmbuild/SPECS/
sed -i -e 's/libedit 1/libedit 0/g' openssh.spec
sed -i -e 's/BuildRequires: util-linux, groff/BuildRequires: util-linux/g' openssh.spec
sed -i -e 's/BuildRequires: fipscheck-devel/#BuildRequires: fipscheck-devel/g' openssh.spec

# build will start from this command
rpmbuild -ba openssh.spec

OPENSSH_VERSION=$(grep "^Source0"  openssh.spec | awk '{print $2}' |xargs basename | sed -r 's/\.[[:alnum:]]+\.[[:alnum:]]+$//')
# shellcheck disable=SC2164
cd ../BUILD/"${OPENSSH_VERSION}"/
make
sudo make install
# make sure you are running tests as user (NOT root user)
[ -d "${OUTPUT}" ] && mv "${OUTPUT}" "${OUTPUT}_$(date +%Y%m%d%H%M%S)"
mkdir -p "${OUTPUT}"
make tests 2>&1 | tee -a "${TEST_LOG}"
parse_output
