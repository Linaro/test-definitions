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
echo $pid
kill $pid
rm -rf /data/data/org.zeroxlab.zeroxbenchmark/files*
rm -rf /data/data/org.zeroxlab.zeroxbenchmark/shared_prefs*

########################################android_0xbenchmark_modify_path.py

source=$PWD/ZeroxBench_Preference.xml
target="/data/data/org.zeroxlab.zeroxbenchmark/shared_prefs/ZeroxBench_Preference.xml"

target_dir="/data/data"

group="None"
owner="None"

group=`ls -l /data/data/|grep org.zeroxlab.zeroxbenchmark|tr -s " "|cut -d \  -f 2`
owner=`ls -l /data/data/|grep org.zeroxlab.zeroxbenchmark|tr -s " "|cut -d \  -f 3`


echo group:$group
echo owner:$owner

target_dir="/data/data/org.zeroxlab.zeroxbenchmark/shared_prefs"


#make dir
mkdir $target_dir
echo "directory created"
#change owner
chown $owner:$group $target_dir
echo "owner changed"
#change mode
chmod 771 $target_dir
echo "mode changed"
#push file
cp $source $target
#change owner
chown $owner:$group $target
#change mode
chmod 660 $target

target_dir="/data/data/org.zeroxlab.zeroxbenchmark/files"

#make dir
mkdir $target_dir
#change owner
chown $owner:$group $target_dir
#change mode
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
cp /data/data/org.zeroxlab.zeroxbenchmark/files/0xBenchmark.bundle /mnt/sdcard/0xBenchmark.bundle


logcat -d | grep "0xbench_test_case:" |tr -s " "|cut -d \  -f 4,5,6,7,8



