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


def fio_device_existence():
    testcase_name = "fio_target_device_existence"
    if sys.argv[1] == "":
        print testcase_name + ": FAIL" + " 0" + " Inapplicable" + " - Device name is empty"
        sys.exit(1)
    else:
        logfile = open("partition_layout.txt", "r")
        logcontent = logfile.readlines()
        positive_counter = 0
        for i in range(0, len(logcontent)):
            print logcontent[i].strip("\n")
            if sys.argv[1] in logcontent[i]:
                positive_counter = positive_counter + 1
        logfile.close()
        if positive_counter > 0:
            print testcase_name + ": PASS" + " 0" + " Inapplicable"
        else:
            print testcase_name + ": FAIL" + " 0" + " Inapplicable" + " - Could not locate " + sys.argv[1] + " on target board"
            sys.exit(1)


def fio_existence():
    testcase_name = "fio_binary_existence"
    run_command = "which fio"
    print run_command

    fio_binary_location = commands.getstatusoutput(run_command)
    if fio_binary_location[0] != 0:
        print testcase_name + ": FAIL" + " 0" + " Inapplicable" + " - Could not locate FIO binary"
        sys.exit(1)
    else:
        print "The FIO binary location is: " + fio_binary_location[1]
        print testcase_name + ": PASS" + " 0" + " Inapplicable"


def fio_read():
    testcase_name = "fio_bs4kread_iops"
    run_command = "sudo fio -filename=" + device_name + " -rw=read -direct=1 -iodepth 1 -thread -ioengine=psync -bs=4k -numjobs=1 -runtime=10 -group_reporting -name=fio_read > fio_read.txt 2>&1"
    print run_command

    fio_read_return = commands.getstatusoutput(run_command)
    print fio_read_return[0]

    if fio_read_return[0] != 0:
        print testcase_name + ": FAIL" + " 0" + " Inapplicable" + " - Command ran failed on " + device_name
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
                target_element = logcontent[i].split(",")
                for j in range(0, len(target_element)):
                    if keyword in target_element[j]:
                        iops_result = target_element[j].split("=")[1].strip(" ")
                        print "The IOPS number in fio_read test is: " + iops_result

        logfile.close()
        print testcase_name + ": PASS" + " " + iops_result + " " + "IOPS"


def fio_randread():
    testcase_name = "fio_randread_iops"
    run_command = "sudo fio -filename=" + device_name + " -rw=randread -direct=1 -iodepth 1 -thread -ioengine=psync -bs=4k -numjobs=1 -runtime=10 -group_reporting -name=fio_randread > fio_randread.txt 2>&1"
    print run_command

    fio_randread_return = commands.getstatusoutput(run_command)
    print fio_randread_return[0]

    if fio_randread_return[0] != 0:
        print testcase_name + ": FAIL" + " 0" + " Inapplicable" + " - Command ran failed on " + device_name
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
                target_element = logcontent[i].split(",")
                for j in range(0, len(target_element)):
                    if keyword in target_element[j]:
                        iops_result = target_element[j].split("=")[1].strip(" ")
                        print "The IOPS number in fio_randread test is: " + iops_result

        logfile.close()
        print testcase_name + ": PASS" + " " + iops_result + " " + "IOPS"


def fio_write():
    testcase_name = "fio_write_iops"
    run_command = "sudo fio -filename=" + device_name + " -rw=write -direct=1 -iodepth 1 -thread -ioengine=psync -bs=4k -numjobs=1 -runtime=10 -group_reporting -name=fio_write > fio_write.txt 2>&1"
    print run_command

    fio_write_return = commands.getstatusoutput(run_command)
    print fio_write_return[0]

    if fio_write_return[0] != 0:
        print testcase_name + ": FAIL" + " 0" + " Inapplicable" + " - Command ran failed on " + device_name
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
                target_element = logcontent[i].split(",")
                for j in range(0, len(target_element)):
                    if keyword in target_element[j]:
                        iops_result = target_element[j].split("=")[1].strip(" ")
                        print "The IOPS number in fio_write test is: " + iops_result

        logfile.close()
        print testcase_name + ": PASS" + " " + iops_result + " " + "IOPS"


def fio_randwrite():
    testcase_name = "fio_randwrite_iops"
    run_command = "sudo fio -filename=" + device_name + " -rw=randwrite -direct=1 -iodepth 1 -thread -ioengine=psync -bs=4k -numjobs=1 -runtime=10 -group_reporting -name=fio_randwrite > fio_randwrite.txt 2>&1"
    print run_command

    fio_randwrite_return = commands.getstatusoutput(run_command)
    print fio_randwrite_return[0]

    if fio_randwrite_return[0] != 0:
        print testcase_name + ": FAIL" + " 0" + " Inapplicable" + " - Command ran failed on " + device_name
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
                target_element = logcontent[i].split(",")
                for j in range(0, len(target_element)):
                    if keyword in target_element[j]:
                        iops_result = target_element[j].split("=")[1].strip(" ")
                        print "The IOPS number in fio_randwrite test is: " + iops_result

        logfile.close()
        print testcase_name + ": PASS" + " " + iops_result + " " + "IOPS"


def fio_512k_write():
    testcase_name = "fio_512k_write_bandwidth"
    run_command = "sudo fio -filename=" + device_name + " -rw=write -direct=1 -iodepth 1 -thread -ioengine=psync -bs=512k -numjobs=1 -runtime=10 -group_reporting -name=fio_512k_write > fio_512k_write.txt 2>&1"
    print run_command

    fio_512k_write_return = commands.getstatusoutput(run_command)
    print fio_512k_write_return[0]

    if fio_512k_write_return[0] != 0:
        print testcase_name + ": FAIL" + " 0" + " Inapplicable" + " - Command ran failed on " + device_name
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
                target_element = logcontent[i].split(",")
                for j in range(0, len(target_element)):
                    if keyword in target_element[j]:
                        bandwidth_result = target_element[j].split("=")[1].strip(" ")
                        print "The Bandwidth number in fio_512k_write test is: " + bandwidth_result
                        bandwidth_number = bandwidth_result.split("/")[0][:-2]

        logfile.close()
        print testcase_name + ": PASS" + " " + bandwidth_number + " " + "KB/s"


def fio_512k_read():
    testcase_name = "fio_512k_read_bandwidth"
    run_command = "sudo fio -filename=" + device_name + " -rw=read -direct=1 -iodepth 1 -thread -ioengine=psync -bs=512k -numjobs=1 -runtime=10 -group_reporting -name=fio_512k_read > fio_512k_read.txt 2>&1"
    print run_command

    fio_512k_read_return = commands.getstatusoutput(run_command)
    print fio_512k_read_return[0]

    if fio_512k_read_return[0] != 0:
        print testcase_name + ": FAIL" + " 0" + " Inapplicable" + " - Command ran failed on " + device_name
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
                target_element = logcontent[i].split(",")
                for j in range(0, len(target_element)):
                    if keyword in target_element[j]:
                        bandwidth_result = target_element[j].split("=")[1].strip(" ")
                        print "The Bandwidth number in fio_512k_read test is: " + bandwidth_result
                        bandwidth_number = bandwidth_result.split("/")[0][:-2]

        logfile.close()
        print testcase_name + ": PASS" + " " + bandwidth_number + " " + "KB/s"

# Run all test
fio_device_existence()
fio_existence()
fio_read()
fio_randread()
fio_write()
fio_randwrite()
fio_512k_write()
fio_512k_read()
