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
import stat
import time
import commands

# Switch to home path of current user to avoid any permission issue
home_path = os.environ['HOME']
os.chdir(home_path)
print os.getcwd()

# List all test cases
test_case_list = ["sata_device_existence", "sata_mklabel_msdos", "sata_mklabel_gpt", "sata_first_ext2_partition", "sata_second_ext2_partition", "sata_ext3_format", "sata_ext4_format", "sata_ext4_mount", "sata_ext4_umount", "sata_ext4_file_fill", "sata_ext4_file_edit", "sata_ext4_dd_write", "sata_ext4_dd_read"]
print "There are " + str(len(test_case_list)) + " test cases in this test suite."


# All skipped - If test case sata_device_existence failed, then skip all the rest.
def all_skipped():
    for element in test_case_list[1:]:
        print element + ": SKIP" + " 0" + " Inapplicable"

# Save partition layout to a local file for reference
commands.getstatusoutput("fdisk -l > partition_layout.txt 2>&1")
device_name = sys.argv[1]


def sata_device_existence():
    testcase_name = "sata_device_existence"
    if device_name == "":
        print testcase_name + ": FAIL" + " 0" + " Inapplicable" + " - Device name is empty"
        all_skipped()
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
            all_skipped()
            sys.exit(1)


def sata_mklabel_msdos():
    testcase_name = "sata_mklabel_msdos"
    label_name = "msdos"
    run_command = "parted -s " + device_name + " mklabel " + label_name
    print run_command

    mklabel_return = commands.getstatusoutput(run_command)
    if mklabel_return[0] != 0:
        print testcase_name + ": FAIL" + " 0" + " Inapplicable"
    else:
        commands.getstatusoutput("parted -s " + device_name + " print > partition_table_msdos.txt 2>&1")
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
    run_command = "parted -s " + device_name + " mklabel " + label_name
    print run_command

    mklabel_return = commands.getstatusoutput(run_command)
    if mklabel_return[0] != 0:
        print testcase_name + ": FAIL" + " 0" + " Inapplicable"
    else:
        commands.getstatusoutput("parted -s " + device_name + " print > partition_table_gpt.txt 2>&1")
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
    partition_table_creation = "parted -s " + device_name + " mklabel " + label_name
    first_partition_creation = "parted -s " + device_name + " mkpart primary ext2 0 10%"
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
            commands.getstatusoutput("fdisk -l " + device_name + " > ext2_msdos_first.txt 2>&1")
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
    second_partition_creation = "parted -s " + device_name + " mkpart primary ext2 11% 20%"
    print second_partition_creation

    second_partition_return = commands.getstatusoutput(second_partition_creation)
    if second_partition_return[0] != 0:
        print testcase_name + ": FAIL" + " 0" + " Inapplicable" + " Failures on " + second_partition_creation
    else:
        commands.getstatusoutput("fdisk -l " + device_name + " > ext2_msdos_second.txt 2>&1")
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
    ext3_format = "mkfs.ext3 " + target_partition_name
    print ext3_format

    ext3_format_return = commands.getstatusoutput(ext3_format)
    if ext3_format_return[0] != 0:
        print testcase_name + ": FAIL" + " 0" + " Inapplicable" + " Failures on ext3 format command"
    else:
        commands.getstatusoutput("parted -s " + device_name + " print > ext3_format_first.txt 2>&1")
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
    ext4_format = "mkfs.ext4 " + target_partition_name
    print ext4_format

    ext4_format_return = commands.getstatusoutput(ext4_format)
    if ext4_format_return[0] != 0:
        print testcase_name + ": FAIL" + " 0" + " Inapplicable" + " Failures on ext4 format command"
    else:
        commands.getstatusoutput("parted -s " + device_name + " print > ext4_format_second.txt 2>&1")
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


def sata_ext4_mount_umount():
    testcase_mount = "sata_ext4_mount"
    testcase_umount = "sata_ext4_umount"
    target_partition_name = device_name + "2"
    mount_point = "/media"
    ext4_mount = "mount " + target_partition_name + " " + mount_point
    ext4_umount = "umount " + mount_point

    # umount everything from mount point - cleaning
    umount_clean = "umount " + mount_point
    commands.getstatusoutput(umount_clean)
    time.sleep(5)
    print "mount point cleaned!"

    # Test mount command
    ext4_mount_return = commands.getstatusoutput(ext4_mount)
    time.sleep(5)
    if ext4_mount_return[0] != 0:
        print testcase_mount + ": FAIL" + " 0" + " Inapplicable" + " Failures on ext4 partition mount!"
    else:
        commands.getstatusoutput("mount > mount_log.txt 2>&1")
        logfile = open("mount_log.txt", "r")
        logcontent = logfile.readlines()
        positive_counter = 0
        for i in range(0, len(logcontent)):
            if target_partition_name in logcontent[i]:
                positive_counter = positive_counter + 1
        logfile.close()
        if positive_counter > 0:
            print testcase_mount + ": PASS" + " 0" + " Inapplicable"
        else:
            print testcase_mount + ": FAIL" + " 0" + " Inapplicable" + " - Could not find ext4 partition in mount log!"

    # Test umount command
    ext4_umount_return = commands.getstatusoutput(ext4_umount)
    time.sleep(5)
    if ext4_umount_return[0] != 0:
        print testcase_umount + ": FAIL" + " 0" + " Inapplicable" + " Failures on ext4 partition umount!"
    else:
        commands.getstatusoutput("mount > umount_log.txt 2>&1")
        logfile = open("umount_log.txt", "r")
        logcontent = logfile.readlines()
        positive_counter = 0
        for i in range(0, len(logcontent)):
            if target_partition_name in logcontent[i]:
                positive_counter = positive_counter + 1
        logfile.close()
        if positive_counter > 0:
            print testcase_umount + ": FAIL" + " 0" + " Inapplicable" + " - ext4 partition umount failed from " + mount_point
        else:
            print testcase_umount + ": PASS" + " 0" + " Inapplicable"


def sata_ext4_file_fill_edit():
    testcase_filefill = "sata_ext4_file_fill"
    testcase_fileedit = "sata_ext4_file_edit"
    target_partition_name = device_name + "2"
    mount_point = "/media"
    ext4_mount = "mount " + target_partition_name + " " + mount_point
    ext4_umount = "umount " + mount_point

    # umount everything from mount point - cleaning
    umount_clean = "umount " + mount_point
    commands.getstatusoutput(umount_clean)
    time.sleep(5)
    print "mount point cleaned!"
    commands.getstatusoutput(ext4_mount)
    time.sleep(5)

    # Create a 1MB file with 0x00 filled in
    file_creation_1M = "dd if=/dev/zero of=/media/file_1MB bs=4k count=256"
    file_creation_1M_return = commands.getstatusoutput(file_creation_1M)
    if file_creation_1M_return[0] != 0:
        print testcase_filefill + ": FAIL" + " 0" + " Inapplicable" + " failed to create a 1MB file filled with 0x00!"
    elif os.path.isfile("/media/file_1MB") == False:
        print testcase_filefill + ": FAIL" + " 0" + " Inapplicable" + " file_1MB can not be found!"
    elif os.path.getsize("/media/file_1MB") != 1048576:
        print testcase_filefill + ": FAIL" + " 0" + " Inapplicable" + " file_1MB size incorrect!"
    else:
        print testcase_filefill + ": PASS" + " 0" + " Inapplicable"

    # Create an empty file then write something into it
    testfile_name = "/media/test_file.txt"
    if os.path.isfile(testfile_name) == True:
        os.unlink(testfile_name)
    file_creation_empty = "touch " + testfile_name
    file_creation_empty_return = commands.getstatusoutput(file_creation_empty)
    if file_creation_empty_return[0] != 0:
        print testcase_fileedit + ": FAIL" + " 0" + " Inapplicable" + " failed to create an empty file!"
    elif os.path.isfile(testfile_name) == False:
        print testcase_fileedit + ": FAIL" + " 0" + " Inapplicable" + " " + testfile_name + " can not be found!"
    else:
        os.chmod(testfile_name, stat.S_IRWXU)
        test_string = "This is a test file"
        testfile = open(testfile_name, "a")
        testfile.write(test_string)
        testfile.close()
        # Validating
        testfile = open(testfile_name, "r")
        return_string = testfile.read()
        if return_string != test_string:
            print testcase_fileedit + ": FAIL" + " 0" + " Inapplicable" + " file content doesn't match!"
        else:
            print testcase_fileedit + ": PASS" + " 0" + " Inapplicable"
        testfile.close()

    # umount everything from mount point - cleaning
    umount_clean = "umount " + mount_point
    commands.getstatusoutput(umount_clean)
    time.sleep(5)
    print "mount point cleaned!"


def sata_ext4_dd_write_read():
    testcase_dd_write = "sata_ext4_dd_write"
    testcase_dd_read = "sata_ext4_dd_read"
    target_partition_name = device_name + "2"
    mount_point = "/media"
    ext4_mount = "mount " + target_partition_name + " " + mount_point
    ext4_umount = "umount " + mount_point

    # umount everything from mount point - cleaning
    umount_clean = "umount " + mount_point
    commands.getstatusoutput(umount_clean)
    time.sleep(5)
    print "mount point cleaned!"
    commands.getstatusoutput(ext4_mount)
    time.sleep(5)

    # Test write speed by using dd, direct write
    dd_write_1G = "dd if=/dev/zero of=/media/file_1GB oflag=direct bs=4k count=262144 > dd_write_1GB_stdout.txt 2>&1"
    dd_write_1G_return = commands.getstatusoutput(dd_write_1G)
    if dd_write_1G_return[0] != 0:
        print testcase_dd_write + ": FAIL" + " 0" + " Inapplicable" + " failed to create a 1GB file using dd!"
    elif os.path.isfile("/media/file_1GB") == False:
        print testcase_dd_write + ": FAIL" + " 0" + " Inapplicable" + " file_1GB can not be found!"
    elif os.path.getsize("/media/file_1GB") != 1073741824:
        print testcase_dd_write + ": FAIL" + " 0" + " Inapplicable" + " file_1GB size incorrect!"
    else:
        target_list = []
        writelog = open("dd_write_1GB_stdout.txt", "r")
        writelog_content = writelog.readlines()
        for item in writelog_content:
            if str(1073741824) in item:
                target_list = item.split(",")[-1].strip("\n").split(" ")
                break
        if target_list == []:
            print testcase_dd_write + ": FAIL" + " 0" + " Inapplicable" + " can not find write performance result."
        elif len(target_list) < 2:
            print testcase_dd_write + ": FAIL" + " 0" + " Inapplicable" + " write test result parsing failed, please check the log output!"
        else:
            print testcase_dd_write + ": PASS" + " " + str(target_list[-2]) + " " + target_list[-1]
        writelog.close()

    # Test read speed by using dd, direct read
    if os.path.isfile("/media/file_1GB") == False:
        print testcase_dd_read + ": FAIL" + " 0" + " Inapplicable" + " can not find the target file to read."
    else:
        dd_read_1G = "dd if=/media/file_1GB iflag=direct of=/dev/null bs=4k count=262144 > dd_read_1GB_stdout.txt 2>&1"
        dd_read_1G_return = commands.getstatusoutput(dd_read_1G)
        if dd_read_1G_return[0] != 0:
            print testcase_dd_read + ": FAIL" + " 0" + " Inapplicable" + " failed to read the target file!"
        else:
            target_list = []
            readlog = open("dd_read_1GB_stdout.txt", "r")
            readlog_content = readlog.readlines()
            for item in readlog_content:
                if str(1073741824) in item:
                    target_list = item.split(",")[-1].strip("\n").split(" ")
                    break
            if target_list == []:
                print testcase_dd_read + ": FAIL" + " 0" + " Inapplicable" + " can not find read performance result."
            elif len(target_list) < 2:
                print testcase_dd_read + ": FAIL" + " 0" + " Inapplicable" + " read test result parsing failed, please check the log output!"
            else:
                print testcase_dd_read + ": PASS" + " " + str(target_list[-2]) + " " + target_list[-1]
            readlog.close()

    # umount and clean
    os.unlink("/media/file_1GB")
    umount_clean = "umount " + mount_point
    commands.getstatusoutput(umount_clean)
    time.sleep(5)
    print "mount point cleaned!"

# Run all test
sata_device_existence()
sata_mklabel_msdos()
sata_mklabel_gpt()
sata_first_ext2_partition()
sata_second_ext2_partition()
sata_ext3_format()
sata_ext4_format()
sata_ext4_mount_umount()
sata_ext4_file_fill_edit()
sata_ext4_dd_write_read()
