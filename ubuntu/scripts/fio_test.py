#!/usr/bin/env python
#
# FIO test cases for Linux Linaro ubuntu
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
# Author: Botao Sun <botao.sun@linaro.org>
#

import sys
import os
import commands

# Switch to home path of current user to avoid any permission issue
home_path = os.environ['HOME']
os.chdir(home_path)
print os.getcwd()

# Save partition layout to a local file for reference
commands.getstatusoutput("sudo fdisk -l > partition_layout.txt 2>&1")
device_name = sys.argv[1]

def fio_installation():
    testcase_name = "fio_installation"
    run_command = "sudo apt-get -y install fio"
    print run_command

    fio_installation_return = commands.getstatusoutput(run_command)
    if fio_installation_return[0] != 0:
        print testcase_name + ": FAIL - Installation Failure!"
    else:
        fio_binary_location = commands.getstatusoutput("which fio")
        if fio_binary_location[0] != 0:
            print testcase_name + ": FAIL - Could not locate FIO binary, something is wrong during the installation"
        else:
            print "The FIO binary location is: " + fio_binary_location[1]
            print testcase_name + ": PASS"

def fio_read():
    testcase_name = "fio_read"
    run_command = "sudo fio -filename=" + device_name + " -rw=read -direct=1 -iodepth 1 -thread -ioengine=psync -bs=4k -numjobs=1 -runtime=10 -group_reporting -name=fio_read > fio_read.txt 2>&1"
    print run_command

    fio_read_return = commands.getstatusoutput(run_command)
    print fio_read_return[0]

    if fio_read_return[0] != 0:
        print testcase_name + ": FAIL - Command ran failed on " + device_name
    else:
        # Print output to stdout
        logfile = open("fio_read.txt", "r")
        logcontent = logfile.readlines()
        for element in logcontent:
            print element.strip("\n")

        # Print IOPS number
        keyword = "iops="
        for i in range(0, len(logcontent)):
            if keyword in logcontent[i]:
                # print logcontent[i]
                target_element = logcontent[i].split(",")
                # print target_element
                for j in range(0, len(target_element)):
                    if keyword in target_element[j]:
                        print "The IOPS number in fio_read test is: " + target_element[j].split("=")[1].strip(" ")

        logfile.close()
        print testcase_name + ": PASS"

def fio_randread():
    testcase_name = "fio_randread"
    run_command = "sudo fio -filename=" + device_name + " -rw=randread -direct=1 -iodepth 1 -thread -ioengine=psync -bs=4k -numjobs=1 -runtime=10 -group_reporting -name=fio_randread > fio_randread.txt 2>&1"
    print run_command

    fio_randread_return = commands.getstatusoutput(run_command)
    print fio_randread_return[0]

    if fio_randread_return[0] != 0:
        print testcase_name + ": FAIL - Command ran failed on " + device_name
    else:
        # Print output to stdout
        logfile = open("fio_randread.txt", "r")
        logcontent = logfile.readlines()
        for element in logcontent:
            print element.strip("\n")

        # Print IOPS number
        keyword = "iops="
        for i in range(0, len(logcontent)):
            if keyword in logcontent[i]:
                # print logcontent[i]
                target_element = logcontent[i].split(",")
                # print target_element
                for j in range(0, len(target_element)):
                    if keyword in target_element[j]:
                        print "The IOPS number in fio_randread test is: " + target_element[j].split("=")[1].strip(" ")

        logfile.close()
        print testcase_name + ": PASS"

def fio_write():
    testcase_name = "fio_write"
    run_command = "sudo fio -filename=" + device_name + " -rw=write -direct=1 -iodepth 1 -thread -ioengine=psync -bs=4k -numjobs=1 -runtime=10 -group_reporting -name=fio_write > fio_write.txt 2>&1"
    print run_command

    fio_write_return = commands.getstatusoutput(run_command)
    print fio_write_return[0]

    if fio_write_return[0] != 0:
        print testcase_name + ": FAIL - Command ran failed on " + device_name
    else:
        # Print output to stdout
        logfile = open("fio_write.txt", "r")
        logcontent = logfile.readlines()
        for element in logcontent:
            print element.strip("\n")

        # Print IOPS number
        keyword = "iops="
        for i in range(0, len(logcontent)):
            if keyword in logcontent[i]:
                # print logcontent[i]
                target_element = logcontent[i].split(",")
                # print target_element
                for j in range(0, len(target_element)):
                    if keyword in target_element[j]:
                        print "The IOPS number in fio_write test is: " + target_element[j].split("=")[1].strip(" ")

        logfile.close()
        print testcase_name + ": PASS"

def fio_randwrite():
    testcase_name = "fio_randwrite"
    run_command = "sudo fio -filename=" + device_name + " -rw=randwrite -direct=1 -iodepth 1 -thread -ioengine=psync -bs=4k -numjobs=1 -runtime=10 -group_reporting -name=fio_randwrite > fio_randwrite.txt 2>&1"
    print run_command

    fio_randwrite_return = commands.getstatusoutput(run_command)
    print fio_randwrite_return[0]

    if fio_randwrite_return[0] != 0:
        print testcase_name + ": FAIL - Command ran failed on " + device_name
    else:
        # Print output to stdout
        logfile = open("fio_randwrite.txt", "r")
        logcontent = logfile.readlines()
        for element in logcontent:
            print element.strip("\n")

        # Print IOPS number
        keyword = "iops="
        for i in range(0, len(logcontent)):
            if keyword in logcontent[i]:
                # print logcontent[i]
                target_element = logcontent[i].split(",")
                # print target_element
                for j in range(0, len(target_element)):
                    if keyword in target_element[j]:
                        print "The IOPS number in fio_randwrite test is: " + target_element[j].split("=")[1].strip(" ")

        logfile.close()
        print testcase_name + ": PASS"

def fio_512k_write():
    testcase_name = "fio_512k_write"
    run_command = "sudo fio -filename=" + device_name + " -rw=write -direct=1 -iodepth 1 -thread -ioengine=psync -bs=512k -numjobs=1 -runtime=10 -group_reporting -name=fio_512k_write > fio_512k_write.txt 2>&1"
    print run_command

    fio_512k_write_return = commands.getstatusoutput(run_command)
    print fio_512k_write_return[0]

    if fio_512k_write_return[0] != 0:
        print testcase_name + ": FAIL - Command ran failed on " + device_name
    else:
        # Print output to stdout
        logfile = open("fio_512k_write.txt", "r")
        logcontent = logfile.readlines()
        for element in logcontent:
            print element.strip("\n")

        # Print Bandwidth number
        keyword = "bw="
        for i in range(0, len(logcontent)):
            if keyword in logcontent[i]:
                # print logcontent[i]
                target_element = logcontent[i].split(",")
                # print target_element
                for j in range(0, len(target_element)):
                    if keyword in target_element[j]:
                        print "The Bandwidth number in fio_512k_write test is: " + target_element[j].split("=")[1].strip(" ")

        logfile.close()
        print testcase_name + ": PASS"

def fio_512k_read():
    testcase_name = "fio_512k_read"
    run_command = "sudo fio -filename=" + device_name + " -rw=read -direct=1 -iodepth 1 -thread -ioengine=psync -bs=512k -numjobs=1 -runtime=10 -group_reporting -name=fio_512k_read > fio_512k_read.txt 2>&1"
    print run_command

    fio_512k_read_return = commands.getstatusoutput(run_command)
    print fio_512k_read_return[0]

    if fio_512k_read_return[0] != 0:
        print testcase_name + ": FAIL - Command ran failed on " + device_name
    else:
        # Print output to stdout
        logfile = open("fio_512k_read.txt", "r")
        logcontent = logfile.readlines()
        for element in logcontent:
            print element.strip("\n")

        # Print Bandwidth number
        keyword = "bw="
        for i in range(0, len(logcontent)):
            if keyword in logcontent[i]:
                # print logcontent[i]
                target_element = logcontent[i].split(",")
                # print target_element
                for j in range(0, len(target_element)):
                    if keyword in target_element[j]:
                        print "The Bandwidth number in fio_512k_read test is: " + target_element[j].split("=")[1].strip(" ")

        logfile.close()
        print testcase_name + ": PASS"

# Run all test
fio_installation()
fio_read()
fio_randread()
fio_write()
fio_randwrite()
fio_512k_write()
fio_512k_read()