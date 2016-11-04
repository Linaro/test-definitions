# you should NOT be root
# run following steps on CentOS as user
sudo yum update
# sslverify=0 to be enabled in all repo files
sudo vim /etc/yum.repos.d/*.repo
sudo yum clean all
sudo yum install autoconf automake binutils bison flex gcc gcc-c++ gettext \
                 libtool make patch pkgconfig redhat-rpm-config rpm-build

sudo yumdownloader --source openssh
# currently installed openssh version rpm package
# File name could be different version
mkdir -p ~/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
echo '%_topdir %(echo $HOME)/rpmbuild' > ~/.rpmmacros
# install openssh dependencies
sudo yum install gtk2-devel libX11-devel openldap-devel zlib-devel \
                 audit-libs-devel groff pam-devel tcp_wrappers-devel \
                 fipscheck-devel openssl-devel krb5-devel libedit-devel \
                 ncurses-devel libselinux-devel xauth
# you may see fipscheck-devel not found
# download fipscheck source and build it
wget https://fedorahosted.org/releases/f/i/fipscheck/fipscheck-1.4.1.tar.bz2
bunzip2 fipscheck-1.4.1.tar.bz2
mkdir fipscheck
cd fipscheck
tar -xvf ../fipscheck-1.4.1.tar
cd fipscheck-1.4.1/
automake
./configure
make
sudo make install
# go to home directory
cd ~/
# run below steps you could see few list of dependencies not met
# we will edit spec file later to fix those issues.
rpmbuild --rebuild openssh-6.6.1p1-31.el7.src.rpm
cd ~/rpmbuild/SPECS/
# edit the spec file carefully
# refer openssh.spec.patch file
vim openssh.spec
# change libedit 1 to 0
# %define libedit 0
# remove groff from below line
# BuildRequires: util-linux, groff
# BuildRequires: util-linux
# comment out fipscheck-devel and libcap-ng-devel
# BuildRequires: fipscheck-devel >= 1.3.0
# BuildRequires: libcap-ng-devel
# build will start from this command
rpmbuild -ba openssh.spec
# after the successful build

cd ../BUILD/openssh-6.6p1/
make
sudo make install
# make sure you are running tests as user (NOT root user)
make tests
