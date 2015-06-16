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
import os, sys, platform, glob, json, pwd
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

# Collect result of the execution of each step of test runs.
def LavaTestCase(TestCommand, TestCaseID):
    if call(TestCommand) == 0:
        call(['lava-test-case', str(TestCaseID), '--result', 'pass'])
        return True
    else:
        call(['lava-test-case', str(TestCaseID), '--result', 'fail'])
        return False

def JsonPaser(ResultFile, TestCaseID, Suffix):
    if not os.path.isfile(ResultFile):
        print '%s not found' % (ResultFile)
        call(['lava-test-case', SubTestCaseID + Suffix, '--result', 'fail'])
    else:
        JsonData = open(ResultFile)
        Data = json.load(JsonData)
        for item in Data:
            call(['lava-test-case', SubTestCaseID + '-' +  item + Suffix, '--result', 'pass', '--measurement', str(Data[item])])
        JsonData.close()

# User existence check
def FindUser(name):
     try:
         return pwd.getpwnam(name)
     except KeyError:
         return None

# pre-config
if not FindUser('lkp'):
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
SplitJob = [LKPPath + '/sbin/split-job', '--no-defaults', '--output', WD + '/' + Job, LKPPath + '/jobs/' + Job + '.yaml']
print 'Splitting job %s with command: %s' % (Job, SplitJob)
if not LavaTestCase(SplitJob, 'split-job-' + Job):
    print '%s split failed.' % (Job)
    sys.exit(1)

# Setup test job.
SubTests = glob.glob(WD + '/' + Job + '/*.yaml')
print 'Sub-tests of %s: %s' % (Job, SubTests)

SetupLocal = [LKPPath + '/bin/setup-local', SubTests[0]]
print 'Set up %s test with command: %s' % (Job, SetupLocal)
if not LavaTestCase(SetupLocal, 'setup-local-' + Job):
    print '%s setup failed.' %(Job)
    sys.exit(1)

# Run tests.
for SubTest in SubTests:
    Count = 1
    while (Count <= Loops):
        SubTestCaseID = os.path.basename(SubTest)[:-5]
        # Add suffix for mutiple runs.
        if Loops > 1:
            Suffix = '-run' + str(Count)
        else:
            Suffix = ''

        RunLocal = [LKPPath + '/bin/run-local', SubTest]
        print 'Running sub-test %s with command: %s' % (SubTestCaseID, RunLocal)
        if not LavaTestCase(RunLocal, 'run-local-' + SubTestCaseID + Suffix):
            print '%s%s test exited with error' % (SubTestCaseID, Suffix)
            continue

        # Decode status.json for each run.
        ResultDir = str('/'.join(['/result', Job, SubTestCaseID[int(len(Job) + 1):], HostName, Dist, Config, KernelVersion]))
        StatsFile = str(ResultDir + '/' + str(Count - 1) + '/'+ 'stats.json')
        JsonPaser(StatsFile, SubTestCaseID, Suffix)

        Count = Count + 1

    # Decode avg.json for mutiple runs.
    if Loops > 1:
        AvgFile = str(ResultDir + '/' + 'avg.json')
        JsonPaser(AvgFile, SubTestCaseID, '-avg')

    # Compress and attach raw data
    call(['tar', 'caf', 'lkp-' + Job + '-result.tar.xz', '/result/' + Job])
    call(['lava-test-run-attach', 'lkp-' + Job + '-result.tar.xz'])
