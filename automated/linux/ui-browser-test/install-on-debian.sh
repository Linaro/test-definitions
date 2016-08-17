#!/bin/bash
#
# Install robotframework and chromedriver
# Copyright © 2016 Linaro Limited
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# Author: Naresh Kamboju <naresh.kamboju@linaro.org>

set -eu
. ../../lib/sh-test-lib
# pre-requirements
pre_requirements () {
    pip install robotframework
    pip install robotframework-selenium2library
}

# For x86_64
install_chromedriver_x86_64 () {
    VERSION="2.20"
    URL="https://chromedriver.storage.googleapis.com/"${VERSION}"/chromedriver_linux64.zip"
    FILE_NAME=$(basename "${URL}")
    KNOWN_SHA256SUM="276c19387d4d66eb4916698f23853444659155cf64c81d9776c7e59969e30ece"
    wget "${URL}"
    validate_check_sum "${FILE_NAME}" "${KNOWN_SHA256SUM}"
    unzip "${FILE_NAME}"
    cp chromedriver /usr/bin/
    chmod 777 /usr/bin/chromedriver
}

install_chromedriver_x86 () {
    VERSION="2.20"
    URL="https://chromedriver.storage.googleapis.com/"${VERSION}"/chromedriver_linux32.zip"
    FILE_NAME=$(basename "${URL}")
    KNOWN_SHA256SUM="f47cb2472d3422c4ed337c16c79dbcabb31cbfd090efe7cf32a99637f5f30661"
    wget "${URL}"
    validate_check_sum "${FILE_NAME}" "${KNOWN_SHA256SUM}"
    unzip "${FILE_NAME}"
    cp chromedriver /usr/bin/
    chmod 777 /usr/bin/chromedriver
}

# For aarch64
install_chromedriver_aarch64 () {
    google_chrome_softlink
    apt-get -y install chromedriver
    cp /usr/lib/chromium/chromedriver /usr/bin/
    chmod 777 /usr/bin/chromedriver
}

# In case of 96boards we pre install chromium on linaro builds
# Officially chromium not supported by robot framework.
# Hack, created a soft link as google-chrome from chromium.
# In the test case we have to mention browser name as chrome.
# But test case opens chromium browser
google_chrome_softlink () {
    cd /usr/bin/
    ln -sf chromium google-chrome
    cd -
}

pre_requirements
ARCH=$(uname -m)
type install_chromedriver_"${ARCH}"
if [ $? -ne 0 ]; then
    echo "Not supported architecture ${ARCH}"
    echo " $0 : failed"
    exit 1
else
    install_chromedriver_"${ARCH}"
fi
