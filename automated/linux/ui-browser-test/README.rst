=====================
Robot framework tests
=====================
Robot Framework is a generic test automation framework for acceptance testing
and acceptance test-driven development (ATDD). It has easy-to-use tabular test
data syntax and it utilizes the keyword-driven testing approach. Its testing
capabilities can be extended by test libraries implemented either with Python
or Java, and users can create new higher-level keywords from existing ones
using the same syntax that is used for creating test cases. reference: [1]

[1] http://robotframework.org/

Requirements
============
- Linux (Debian / Ubuntu / Openembedded / Fedora based)
- Python 2.7
- python-pip
- robotframework
- robotframework-selenium2library
- Web-Browser (firefox, google-chrome or chromium)
- chromedriver
- google-chrome / chromium / firefox

Installation and Run
=====================
If you are on Debian or Ubuntu please run

be a root
# ./install-on-debian.sh
# ./ui-browser-test.sh -u linaro -s false

Basic Usage
===========
robot testcase-name.robot

Examples
--------
robot chrome-test.robot
robot chromium-test.robot
robot firefox-test.robot
robot login-lava.robot
robot youtube-play-bkk16.robot
robot youtube-play.robot

Run all tests in the current directory
python -m robot .

NOTES
=====
Ensure you have right PATH exported before running tests

For more information on usage:
https://github.com/robotframework/robotframework/blob/master/INSTALL.rst
