#!/bin/bash
#
# Install robotframework and chromedriver
# Copyright (C) 2016 Linaro Limited
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
# Python based PIP requirements
pip_requirements () {
    pip install robotframework
    pip install robotframework-selenium2library
}

# For Debian and related distros
install_chromedriver_debian () {
    google_chrome_softlink
    apt-get -y install chromedriver
    cp /usr/lib/chromium/chromedriver /usr/bin/
    chmod 777 /usr/bin/chromedriver
}

# For OE
install_chromedriver_oe-rpb () {
    cp /usr/bin/chromium/chromedriver /usr/bin/
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

dist_name

# Consider Ubuntu as a Debian distribution
dist=${dist/ubuntu/debian}

type install_chromedriver_"${dist}"
if [ $? -ne 0 ]; then
    echo "Distro not supported: ${dist}"
    echo " $0 : failed"
    exit 1
else
    install_chromedriver_"${dist}"
fi

pip_requirements
