#!/system/bin/sh
#
# gtest test case for Linux Linaro Android
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
#         Milosz Wasilewski <milosz.wasilewski@linaro.org>
#

TESTS=$1
ScriptDIR="`pwd`"
FilesDIR="/data/data/org.linaro.gparser/files"

# Download and install gparser.apk
wget http://testdata.validation.linaro.org/tools/gparser.apk
chmod -R 777 $ScriptDIR
pm install "$ScriptDIR/gparser.apk"
mkdir $FilesDIR
# Print the most recent 50 lines and exit logcat
logcat -t 50

for i in $TESTS; do
    # Use the last field as test case name, NF refers to the
    # number of fields of the whole string.
    TestCaseName="`echo $i |awk -F '/' '{print $NF}'`"

    if [ -f $i ]; then
        chmod 755 $i
        LOOPS=$2
        Count=1
    else
        echo "$i file NOT found."
        lava-test-case $TestCaseName --result fail
        continue
    fi

    while [ $Count -le $LOOPS ]; do
        # Run tests.
        echo "Running $TestCaseName tests (iteration $Count) . . ."
        # Nonzero exit code will terminate test script, use "||true" as work around.
        $i --gtest_output="xml:$ScriptDIR/$TestCaseName-$Count.xml" || true
        if [ -f $ScriptDIR/$TestCaseName-$Count.xml ]; then
            echo "Generated XML report successfully."
        else
            echo "$TestCaseName-$Count XML report NOT found."
            lava-test-case $TestCaseName --result fail
            continue
        fi

        # Parse test result.
        cp $ScriptDIR/$TestCaseName-$Count.xml $FilesDIR/TestResults.xml
        chmod -R 777 $FilesDIR
        # Start gparser MainActivity, TestResults.xml will be parsed automatically.
        # Parsed result will be saved as ParsedTestResults.txt under the same directory.
        am start -n org.linaro.gparser/.MainActivity
        sleep 15
        # Stop gparser for the next loop.
        am force-stop org.linaro.gparser
        # Print the most recent 50 lines and exit logcat
        logcat -t 50
        if [ -f $FilesDIR/ParsedTestResults.txt ]; then
            echo "XML report parsed successfully."
            mv $FilesDIR/ParsedTestResults.txt $ScriptDIR/$TestCaseName-$Count.ParsedTestResults.txt
        else
            echo "Failed to parse $TestCaseName-$Count test result."
            lava-test-case $TestCaseName --result fail
            continue
        fi

        # Collect test results.
        while read line; do
                TestCaseID="`echo $line | awk '{print $1}'`"
                TestResult="`echo $line | awk '{print $2}'`"
                TestDuration="`echo $line | awk '{print $3}'`"
                # Use test case name as prefix to amend TestCaseID.
                lava-test-case $TestCaseName.$TestCaseID --result $TestResult --measurement $TestDuration --units s
        done < $ScriptDIR/$TestCaseName-$Count.ParsedTestResults.txt

        Count=$((Count+1))
    done
done

# Uninstall gparser
pm uninstall org.linaro.gparser
