#!/usr/bin/env python
#
# Run LKP test suite on Linaro ubuntu
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
import os, sys, platform, glob, json, pwd, shutil
from subprocess import call

LKPPath = str(sys.argv[1])
print 'LKP test suite path: %s' % (LKPPath)
WD = str(sys.argv[2])
print 'Working directory: %s' % (WD)
Loops = int(sys.argv[3])
Job = str(sys.argv[4])
print 'Going to run %s %s times' % (Job, Loops)
HostName = platform.node()
KernelVersion = platform.release()
Dist = str.lower(platform.dist()[0])
Config = 'defconfig'

# For each step of test run, print pass or fail to test log.
def test_result(TestCommand, TestCaseID):
    if call(TestCommand) == 0:
        print '%s pass' % (TestCaseID)
        return True
    else:
        print '%s fail' % (TestCaseID)
        return False

# User existence check.
def find_user(name):
     try:
         return pwd.getpwnam(name)
     except KeyError:
         return None

# pre-config.
if not find_user('lkp'):
     print 'creating user lkp...'
     call(['useradd', '--create-home', '--home-dir', '/home/lkp', 'lkp'])
else:
     print 'User lkp already exists.'

if not os.path.exists('/home/lkp'):
    call(['mkdir', '-p', '/home/lkp'])

call(['chown', '-R', 'lkp:lkp', '/home/lkp'])

f = open('/etc/apt/sources.list.d/multiverse.list','w')
f.write('deb http://ports.ubuntu.com/ubuntu-ports/ vivid multiverse\n')
f.close()
call(['apt-get', 'update'])

# Split test job.
if not os.path.exists(WD + '/' + Job):
    os.makedirs(WD + '/' + Job)
SplitJob = [LKPPath + '/sbin/split-job', '--output', WD + '/' + Job, LKPPath + '/jobs/' + Job + '.yaml']
print 'Splitting job %s with command: %s' % (Job, SplitJob)
if not test_result(SplitJob, 'split-job-' + Job):
    sys.exit(1)

# Setup test job.
SubTests = glob.glob(WD + '/' + Job + '/*.yaml')
print 'Sub-tests of %s: %s' % (Job, SubTests)
SetupLocal = [LKPPath + '/bin/setup-local', SubTests[0]]
print 'Set up %s test with command: %s' % (Job, SetupLocal)
if not test_result(SetupLocal, 'setup-local-' + Job):
    sys.exit(1)

# Delete test results from last lava-test-shell-run.
if os.path.exists('/result/'):
    shutil.rmtree('/result/', ignore_errors=True)

# Run tests.
for SubTest in SubTests:
    Count = 1
    Done = True
    SubTestCaseID = os.path.basename(SubTest)[:-5]
    ResultRoot = str('/'.join(['/result', Job, SubTestCaseID[int(len(Job) + 1):], HostName, Dist, Config, KernelVersion]))
    while (Count <= Loops):
        # Use suffix for mutiple runs.
        if Loops > 1:
            Suffix = '-run' + str(Count)
        else:
            Suffix = ''

        RunLocal = [LKPPath + '/bin/run-local', SubTest]
        print 'Running test %s%s with command: %s' % (SubTestCaseID, Suffix, RunLocal)
        if not test_result(RunLocal, 'run-local-' + SubTestCaseID + Suffix):
            Done = False
            break

        # For each run, decode Job.json to pick up the scores produced by the benchmark itself.
        ResultFile = ResultRoot + '/' + str(Count - 1) + '/'+ Job + '.json'
        if not os.path.isfile(ResultFile):
            print '%s not found' % (ResultFile)
        else:
            JsonData = open(ResultFile)
            Dict = json.load(JsonData)
            for item in Dict:
                call(['lava-test-case', SubTestCaseID + '-' + item + Suffix, '--result', 'pass', '--measurement', str(Dict[item][0])])
            JsonData.close()

        Count = Count + 1

    # For mutiple runs, if all runs are completed and results found, decode avg.json.
    if Loops > 1 and Done == True:
        AvgFile = ResultRoot + '/' + 'avg.json'
        if not os.path.isfile(ResultFile):
            print '%s not found' % (ResultFile)
        elif not os.path.isfile(AvgFile):
            print '%s not found' % (AvgFile)
        else:
            JsonData = open(ResultFile)
            AvgJsonData = open(AvgFile)
            Dict = json.load(JsonData)
            AvgDict = json.load(AvgJsonData)
            for item in Dict:
                if item in AvgDict:
                    call(['lava-test-case', SubTestCaseID + '-' + item + '-avg', '--result', 'pass', '--measurement', str(AvgDict[item])])
            JsonData.close()
            AvgJsonData.close()

    # Compress and attach raw data.
    call(['tar', 'caf', 'lkp-result-' + Job + '.tar.xz', ResultRoot])
    call(['lava-test-run-attach', 'lkp-result-' + Job + '.tar.xz'])

if Done == False:
    sys.exit(1)
else:
    sys.exit(0)
