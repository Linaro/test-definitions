#!/system/bin/sh
CONSOLE_SECONDS=`dmesg | grep "mounted filesystem with ordered data mode" | tail -n 1 | tr -s " " | cut -d [ -f 2 | cut -d ] -f 1`
LOGCAT_START=`logcat -d -v time | grep "debuggerd" | head -n 1 | cut -d " " -f 2`
LOGCAT_START_HOURS=`echo $LOGCAT_START | cut -d : -f 1`
LOGCAT_START_MINUTES=`echo $LOGCAT_START | cut -d : -f 2`
LOGCAT_START_SECONDS=`echo $LOGCAT_START | cut -d : -f 3 | cut -d . -f 1`
LOGCAT_START_MILLIS=`echo $LOGCAT_START | cut -d : -f 3 | cut -d . -f 2`
echo "$LOGCAT_START_HOURS 3600 * $LOGCAT_START_MINUTES 60 * $LOGCAT_START_SECONDS $LOGCAT_START_MILLIS 0.001 * + + + p"
START_SECONDS=`echo "$LOGCAT_START_HOURS 3600 * $LOGCAT_START_MINUTES 60 * $LOGCAT_START_SECONDS $LOGCAT_START_MILLIS 0.001 * + + + p" | dc`

LOGCAT_END=`logcat -d -v time | grep "Boot animation" | head -n 1 | cut -d " " -f 2`
LOGCAT_END_HOURS=`echo $LOGCAT_END | cut -d : -f 1`
LOGCAT_END_MINUTES=`echo $LOGCAT_END | cut -d : -f 2`
LOGCAT_END_SECONDS=`echo $LOGCAT_END | cut -d : -f 3 | cut -d . -f 1`
LOGCAT_END_MILLIS=`echo $LOGCAT_END | cut -d : -f 3 | cut -d . -f 2`
echo "$LOGCAT_END_HOURS 3600 * $LOGCAT_END_MINUTES 60 * $LOGCAT_END_SECONDS $LOGCAT_END_MILLIS 0.001 * + + + p"
END_SECONDS=`echo "$LOGCAT_END_HOURS 3600 * $LOGCAT_END_MINUTES 60 * $LOGCAT_END_SECONDS $LOGCAT_END_MILLIS 0.001 * + + + p" | dc`

echo "$CONSOLE_SECONDS $END_SECONDS $START_SECONDS - + p"
TOTAL_SECONDS=`echo "$CONSOLE_SECONDS $END_SECONDS $START_SECONDS - + p" | dc`
echo "TEST ANDROID_BOOT_TIME: $TOTAL_SECONDS pass"
