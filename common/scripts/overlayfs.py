#!/usr/bin/env python
#
# Run overlay filesystem test from unionmount testsuite on Linaro ubuntu and
# OpenEmbedded.
#
# Copyright (C) 2012 - 2014, Linaro Limited.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# Author: Chase Qi <chase.qi@linaro.org>
#
import os
import sys
import subprocess

TestSuitePath = sys.argv[1]
TermSlashList = ['0', '1']
TESTS = ['open-plain',
         'open-trunc',
         'open-creat',
         'open-creat-trunc',
         'open-creat-excl',
         'open-creat-excl-trunc',
         'noent-plain',
         'noent-trunc',
         'noent-creat',
         'noent-creat-trunc',
         'noent-creat-excl',
         'noent-creat-excl-trunc',
         'sym1-plain',
         'sym1-trunc',
         'sym1-creat',
         'sym1-creat-excl',
         'sym2-plain',
         'sym2-trunc',
         'sym2-creat',
         'sym2-creat-excl',
         'symx-plain',
         'symx-trunc',
         'symx-creat',
         'symx-creat-excl',
         'symx-creat-trunc',
         'truncate',
         'dir-open',
         'dir-weird-open',
         'dir-open-dir',
         'dir-weird-open-dir',
         'dir-sym1-open',
         'dir-sym1-weird-open',
         'dir-sym2-open',
         'dir-sym2-weird-open',
         'readlink',
         'mkdir',
         'rmdir',
         'hard-link',
         'hard-link-dir',
         'hard-link-sym',
         'unlink',
         'rename-file',
         'rename-empty-dir',
         'rename-new-dir',
         'rename-pop-dir',
         'rename-new-pop-dir',
         'rename-move-dir',
         'rename-mass',
         'rename-mass-2',
         'rename-mass-3',
         'rename-mass-4',
         'rename-mass-5',
         'rename-mass-dir',
         'rename-mass-sym',
         'impermissible']

if os.path.isfile('/usr/bin/python3'):
    PYTHON = 'python3'
else:
    PYTHON = 'python'
PythonVersion = subprocess.check_output([PYTHON, '--version'])
print 'Running tests with: ' + PythonVersion

for TEST in TESTS:
    for TermSlash in TermSlashList:
        if TermSlash == '1':
            SUFFIX = '-termslash'
        else:
            SUFFIX = ''

        TestCommand = [PYTHON, TestSuitePath + '/run', '--ov',
                       '--ts=' + TermSlash, TEST]
        print 'Running %s with command: %s' % (TEST, TestCommand)
        if subprocess.call(TestCommand) == 0:
            subprocess.call(['lava-test-case', TEST + SUFFIX,
                             '--result', 'pass'])
        else:
            subprocess.call(['lava-test-case', TEST + SUFFIX,
                             '--result', 'fail'])
