#!/system/bin/sh
#
# 0xbench test.
#
# Copyright (C) 2012, Linaro Limited.
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
# Foundation, Inc., 51	 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
# owner: harigopal.gollamudi@linaro.org


#######################################android_0xbenchmark_kill.py

pid=`ps |grep org.zeroxlab.zeroxbenchmark|tr -s " "|cut -d' ' -f2`
kill $pid
rm -rf /data/data/org.zeroxlab.zeroxbenchmark/files*
rm -rf /data/data/org.zeroxlab.zeroxbenchmark/shared_prefs*

########################################android_0xbenchmark_modify_path.py

source=$PWD/android/scripts/0xbench/ZeroxBench_Preference.xml
target="/data/data/org.zeroxlab.zeroxbenchmark/shared_prefs/ZeroxBench_Preference.xml"

target_dir="/data/data"

group="None"
owner="None"

group=`ls -l /data/data/|grep org.zeroxlab.zeroxbenchmark|tr -s " "|cut -d \  -f 2`
owner=`ls -l /data/data/|grep org.zeroxlab.zeroxbenchmark|tr -s " "|cut -d \  -f 3`

target_dir="/data/data/org.zeroxlab.zeroxbenchmark/shared_prefs"
mkdir $target_dir
chown $owner:$group $target_dir
chmod 771 $target_dir
cp $source $target

chown $owner:$group $target
chmod 660 $target
target_dir="/data/data/org.zeroxlab.zeroxbenchmark/files"
mkdir $target_dir
chown $owner:$group $target_dir
chmod 771 $target_dir

########################################0xbench.py

save_dir="/data/data/org.zeroxlab.zeroxbenchmark/files"

#options to come from app which runs activity manager
logcat -c

am start -n org.zeroxlab.zeroxbenchmark/org.zeroxlab.zeroxbenchmark.Benchmark --ez autorun true --ez math true --ez 2d true 


########################################

while [ ! -f /data/data/org.zeroxlab.zeroxbenchmark/files/0xBenchmark.bundle ]
do
  sleep 2
done

logcat -d | grep "0xbench_test_case:" |tr -s " "|cut -d \  -f 4,5,6,7,8 > 0xBenchmarkresult.txt
cat 0xBenchmarkresult.txt
