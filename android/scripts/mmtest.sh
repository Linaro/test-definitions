#!/system/bin/sh
#
# mmtest test.
#
# Copyright (C) 2013, Linaro Limited.
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
# Foundation, Inc., 51   Franklin Street, Fifth Floor, Boston, MA  02110-1301,
# USA.
#
# owner: harigopal.gollamudi@linaro.org
#
###############################################################################

cd /mnt/sdcard
logcat -c

echo "mmtest start"

netcfg eth0 dhcp
setprop net.dns1 8.8.8.8

echo "Content downloading"

cd /mnt/media_rw/sdcard0
mkdir media_api
cd media_api

wget http://samplemedia.linaro.org/Mmtest/media_api/goldenThumbnail.png

mkdir music
mkdir video
mkdir videoeditor

cd music
wget http://samplemedia.linaro.org/Mmtest/media_api/music/MP3_48KHz_128kbps_s_1_17.mp3
wget http://samplemedia.linaro.org/Mmtest/media_api/music/MP3_48KHz_128kbps_s_1_17_ABR.mp3
wget http://samplemedia.linaro.org/Mmtest/media_api/music/MP3_48KHz_128kbps_s_1_17_CBR.mp3
wget http://samplemedia.linaro.org/Mmtest/media_api/music/MP3_48KHz_128kbps_s_1_17_ID3V1.mp3
wget http://samplemedia.linaro.org/Mmtest/media_api/music/MP3_48KHz_128kbps_s_1_17_ID3V1_ID3V2.mp3
wget http://samplemedia.linaro.org/Mmtest/media_api/music/MP3_48KHz_128kbps_s_1_17_ID3V2.mp3
wget http://samplemedia.linaro.org/Mmtest/media_api/music/MP3_48KHz_128kbps_s_1_17_VBR.mp3
wget http://samplemedia.linaro.org/Mmtest/media_api/music/SHORTMP3.mp3
wget http://samplemedia.linaro.org/Mmtest/media_api/music/ants.mid
wget http://samplemedia.linaro.org/Mmtest/media_api/music/bzk_chic.wav
wget http://samplemedia.linaro.org/Mmtest/media_api/music/sine_200+1000Hz_44K_mo.wav
wget http://samplemedia.linaro.org/Mmtest/media_api/music/test_amr_ietf.amr

cd ../video
wget http://samplemedia.linaro.org/Mmtest/media_api/video/H263_56_AAC_24.3gp
wget http://samplemedia.linaro.org/Mmtest/media_api/video/H263_56_AMRNB_6.3gp
wget http://samplemedia.linaro.org/Mmtest/media_api/video/H263_500_AMRNB_12.3gp
wget http://samplemedia.linaro.org/Mmtest/media_api/video/H264_320_AAC_64.3gp
wget http://samplemedia.linaro.org/Mmtest/media_api/video/H264_320_AMRNB_6.3gp
wget http://samplemedia.linaro.org/Mmtest/media_api/video/H264_500_AAC_128.3gp
wget http://samplemedia.linaro.org/Mmtest/media_api/video/H264_HVGA_500_NO_AUDIO.3gp
wget http://samplemedia.linaro.org/Mmtest/media_api/video/H264_QVGA_500_NO_AUDIO.3gp
wget http://samplemedia.linaro.org/Mmtest/media_api/video/MPEG4_320_AAC_64.mp4
wget http://samplemedia.linaro.org/Mmtest/media_api/video/big-buck-bunny_trailer.webm
wget http://samplemedia.linaro.org/Mmtest/media_api/video/border_large.3gp

cd ../videoeditor
wget http://samplemedia.linaro.org/Mmtest/media_api/videoeditor/AACLC_44.1kHz_256kbps_s_1_17.mp4
wget http://samplemedia.linaro.org/Mmtest/media_api/videoeditor/AACLC_48KHz_256Kbps_s_1_17.3gp
wget http://samplemedia.linaro.org/Mmtest/media_api/videoeditor/AMRNB_8KHz_12.2Kbps_m_1_17.3gp
wget http://samplemedia.linaro.org/Mmtest/media_api/videoeditor/H263_profile0_176x144_10fps_96kbps_0_25.3gp
wget http://samplemedia.linaro.org/Mmtest/media_api/videoeditor/H263_profile0_176x144_10fps_256kbps_0_25.3gp
wget http://samplemedia.linaro.org/Mmtest/media_api/videoeditor/H263_profile0_176x144_10fps_256kbps_1_17.3gp
wget http://samplemedia.linaro.org/Mmtest/media_api/videoeditor/H263_profile0_176x144_15fps_128kbps_1_35.3gp
wget http://samplemedia.linaro.org/Mmtest/media_api/videoeditor/H263_profile0_176x144_15fps_256kbps_AACLC_16kHz_32kbps_m_0_26.3gp
wget http://samplemedia.linaro.org/Mmtest/media_api/videoeditor/H263_profile0_176x144_15fps_256kbps_AACLC_32kHz_128kbps_s_0_26.3gp
wget http://samplemedia.linaro.org/Mmtest/media_api/videoeditor/H263_profile0_176x144_15fps_256kbps_AACLC_32kHz_128kbps_s_1_17.3gp
wget http://samplemedia.linaro.org/Mmtest/media_api/videoeditor/H264_BP_176x144_15fps_144kbps_AMRNB_8kHz_12.2kbps_m_1_17.3gp
wget http://samplemedia.linaro.org/Mmtest/media_api/videoeditor/H264_BP_640x480_12.5fps_256kbps_AACLC_16khz_24kbps_s_0_26.mp4
wget http://samplemedia.linaro.org/Mmtest/media_api/videoeditor/H264_BP_640x480_15fps_384kbps_60_0.mp4
wget http://samplemedia.linaro.org/Mmtest/media_api/videoeditor/H264_BP_640x480_15fps_1200Kbps_AACLC_48KHz_32kbps_m_1_17.3gp
wget http://samplemedia.linaro.org/Mmtest/media_api/videoeditor/H264_BP_640x480_12.5fps_256kbps_AACLC_16khz_24kbps_s_0_26.mp4
wget http://samplemedia.linaro.org/Mmtest/media_api/videoeditor/H264_BP_640x480_15fps_384kbps_60_0.mp4


if [ -f /mnt/media_rw/sdcard0/media_api/music/test_amr_ietf.amr ]
then
echo "file is downloaded"
fi

logcat -c

am instrument -r -e targetDir  /storage/sdcard0/media_api/music -w com.android.mediaframeworktest/.MediaFrameworkTestRunner > stdout.log 

egrep "INSTRUMENTATION_STATUS: test=|INSTRUMENTATION_STATUS_CODE:" stdout.log |cut -d'=' -f 2 |cut -d ':' -f 2 |xargs -n 4 |sed -e 's/0/pass/g' -e 's/-1/fail/g' -e 's/-2/fail/g' | awk '{$1=""; print $3" "$4}'
