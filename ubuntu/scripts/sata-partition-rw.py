#!/usr/bin/env python
#
# SATA Partition, Read and Write test cases for Linux Linaro ubuntu
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

def sata_device_existence():
    testcase_name = "sata_device_existence"
    if device_name == "":
        print testcase_name + ": FAIL" + " 0" + " Inapplicable" + " - Device name is empty"
        sys.exit(1)
    else:
        logfile = open("partition_layout.txt", "r")
        logcontent = logfile.readlines()
        positive_counter = 0
        for i in range(0, len(logcontent)):
            print logcontent[i].strip("\n")
            if device_name in logcontent[i]:
                positive_counter = positive_counter + 1
        logfile.close()
        if positive_counter > 0:
            print testcase_name + ": PASS" + " 0" + " Inapplicable"
        else:
            print testcase_name + ": FAIL" + " 0" + " Inapplicable" + " - Could not locate " + device_name + " on target board"
            sys.exit(1)

def sata_mklabel_msdos():
    testcase_name = "sata_mklabel_msdos"
    label_name = "msdos"
    run_command = "sudo parted -s " + device_name + " mklabel " + label_name
    print run_command

    mklabel_return = commands.getstatusoutput(run_command)
    if mklabel_return[0] != 0:
        print testcase_name + ": FAIL" + " 0" + " Inapplicable"
    else:
        commands.getstatusoutput("sudo parted -s " + device_name + " print > partition_table_msdos.txt 2>&1")
        logfile = open("partition_table_msdos.txt", "r")
        logcontent = logfile.readlines()
        positive_counter = 0
        for i in range(0, len(logcontent)):
            print logcontent[i].strip("\n")
            if label_name in logcontent[i]:
                positive_counter = positive_counter + 1
        logfile.close()

        if positive_counter > 0:
            print testcase_name + ": PASS" + " 0" + " Inapplicable"
        else:
            print testcase_name + ": FAIL" + " 0" + " Inapplicable" + " - Could not find partition table " + label_name + " on " + device_name

def sata_mklabel_gpt():
    testcase_name = "sata_mklabel_gpt"
    label_name = "gpt"
    run_command = "sudo parted -s " + device_name + " mklabel " + label_name
    print run_command

    mklabel_return = commands.getstatusoutput(run_command)
    if mklabel_return[0] != 0:
        print testcase_name + ": FAIL" + " 0" + " Inapplicable"
    else:
        commands.getstatusoutput("sudo parted -s " + device_name + " print > partition_table_gpt.txt 2>&1")
        logfile = open("partition_table_gpt.txt", "r")
        logcontent = logfile.readlines()
        positive_counter = 0
        for i in range(0, len(logcontent)):
            print logcontent[i].strip("\n")
            if label_name in logcontent[i]:
                positive_counter = positive_counter + 1
        logfile.close()

        if positive_counter > 0:
            print testcase_name + ": PASS" + " 0" + " Inapplicable"
        else:
            print testcase_name + ": FAIL" + " 0" + " Inapplicable" + " - Could not find partition table " + label_name + " on " + device_name

def sata_first_ext2_partition():
    testcase_name = "sata_first_ext2_partition"
    label_name = "msdos"
    partition_table_creation = "sudo parted -s " + device_name + " mklabel " + label_name
    first_partition_creation = "sudo parted -s " + device_name + " mkpart primary ext2 0 10%"
    print partition_table_creation
    print first_partition_creation

    partition_table_return = commands.getstatusoutput(partition_table_creation)
    if partition_table_return[0] != 0:
        print testcase_name + ": FAIL" + " 0" + " Inapplicable" + " Failures on " + partition_table_creation
    else:
        first_partition_return = commands.getstatusoutput(first_partition_creation)
        if first_partition_return[0] != 0:
            print testcase_name + ": FAIL" + " 0" + " Inapplicable" + " Failures on " + first_partition_creation
        else:
            commands.getstatusoutput("sudo fdisk -l " + device_name + " > ext2_msdos_first.txt 2>&1")
            logfile = open("ext2_msdos_first.txt", "r")
            logcontent = logfile.readlines()
            positive_counter = 0
            partition_name_first = device_name + "1"
            for i in range(0, len(logcontent)):
                print logcontent[i].strip("\n")
                if partition_name_first in logcontent[i]:
                    positive_counter = positive_counter + 1
            logfile.close()

            if positive_counter > 0:
                print testcase_name + ": PASS" + " 0" + " Inapplicable"
            else:
                print testcase_name + ": FAIL" + " 0" + " Inapplicable" + " - Could not find partition " + partition_name_first + " on " + device_name

def sata_second_ext2_partition():
    testcase_name = "sata_second_ext2_partition"
    second_partition_creation = "sudo parted -s " + device_name + " mkpart primary ext2 11% 20%"
    print second_partition_creation

    second_partition_return = commands.getstatusoutput(second_partition_creation)
    if second_partition_return[0] != 0:
        print testcase_name + ": FAIL" + " 0" + " Inapplicable" + " Failures on " + second_partition_creation
    else:
        commands.getstatusoutput("sudo fdisk -l " + device_name + " > ext2_msdos_second.txt 2>&1")
        logfile = open("ext2_msdos_second.txt", "r")
        logcontent = logfile.readlines()
        positive_counter = 0
        partition_name_second = device_name + "2"
        for i in range(0, len(logcontent)):
            print logcontent[i].strip("\n")
            if partition_name_second in logcontent[i]:
                positive_counter = positive_counter + 1
        logfile.close()

        if positive_counter > 0:
            print testcase_name + ": PASS" + " 0" + " Inapplicable"
        else:
            print testcase_name + ": FAIL" + " 0" + " Inapplicable" + " - Could not find partition " + partition_name_second + " on " + device_name

def sata_ext3_format():
    testcase_name = "sata_ext3_format"
    target_partition_name = device_name + "1"
    ext3_format = "sudo mkfs.ext3 " + target_partition_name
    print ext3_format

    ext3_format_return = commands.getstatusoutput(ext3_format)
    if ext3_format_return[0] != 0:
        print testcase_name + ": FAIL" + " 0" + " Inapplicable" + " Failures on ext3 format command"
    else:
        commands.getstatusoutput("sudo parted -s " + device_name + " print > ext3_format_first.txt 2>&1")
        logfile = open("ext3_format_first.txt", "r")
        logcontent = logfile.readlines()
        positive_counter = 0
        for i in range(0, len(logcontent)):
            print logcontent[i].strip("\n")
            if "ext3" in logcontent[i]:
                positive_counter = positive_counter + 1
        logfile.close()

        if positive_counter > 0:
            print testcase_name + ": PASS" + " 0" + " Inapplicable"
        else:
            print testcase_name + ": FAIL" + " 0" + " Inapplicable" + " - Could not find ext3 partition on " + device_name

def sata_ext4_format():
    testcase_name = "sata_ext4_format"
    target_partition_name = device_name + "2"
    ext4_format = "sudo mkfs.ext4 " + target_partition_name
    print ext4_format

    ext4_format_return = commands.getstatusoutput(ext4_format)
    if ext4_format_return[0] != 0:
        print testcase_name + ": FAIL" + " 0" + " Inapplicable" + " Failures on ext4 format command"
    else:
        commands.getstatusoutput("sudo parted -s " + device_name + " print > ext4_format_second.txt 2>&1")
        logfile = open("ext4_format_second.txt", "r")
        logcontent = logfile.readlines()
        positive_counter = 0
        for i in range(0, len(logcontent)):
            print logcontent[i].strip("\n")
            if "ext4" in logcontent[i]:
                positive_counter = positive_counter + 1
        logfile.close()

        if positive_counter > 0:
            print testcase_name + ": PASS" + " 0" + " Inapplicable"
        else:
            print testcase_name + ": FAIL" + " 0" + " Inapplicable" + " - Could not find ext4 partition on " + device_name

# Run all test
sata_device_existence()
sata_mklabel_msdos()
sata_mklabel_gpt()
sata_first_ext2_partition()
sata_second_ext2_partition()
sata_ext3_format()
sata_ext4_format()