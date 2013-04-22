#!/system/bin/sh
#
# Skia test.
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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# Author: Fahad Kunnathadi <fahad.k@linaro.org>
# Author: HariGopal <harigopal.gollamudi@linaro.org>

skia_test_exec(){

    logcat -c

    DIRECTORY=$1 
    if [ ! -d "$DIRECTORY"  ]; then
	 mkdir $DIRECTORY;
    fi  

    SKIA_TEST=$2
    if [ -e "$DIRECTORY/$SKIA_TEST.txt" ]; then
	#echo "File exists for $SKIA_TEST"
	rm -f $DIRECTORY/$SKIA_TEST.txt
    else
	touch "$DIRECTORY/$SKIA_TEST.txt"	
    fi

	touch "$DIRECTORY/tmp.txt"	
    OPTIONS=$3
   
    #echo "skia test executing: $SKIA_TEST"
    skia_bench -repeat $OPTIONS -timers w -config 565 -match $SKIA_TEST
    #echo "skia writing into $DIRECTORY/$SKIA_TEST.txt"

    logcat -d | grep "running bench" |tr -s " "|cut -d \  -f 8,9,10,12,14
    #logcat -d -s "skia:*" > $DIRECTORY/tmp.txt
    #awk -F':' '{print $2 $3}' $DIRECTORY/tmp.txt > $DIRECTORY/$SKIA_TEST.txt
	
}

DEFAULT_PATH="/data/skia"

logcat -c

skia_test_exec $DEFAULT_PATH rects 1000
skia_test_exec $DEFAULT_PATH bitmap 1000
skia_test_exec $DEFAULT_PATH repeat 1000
