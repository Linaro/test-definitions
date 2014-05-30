#!/system/bin/sh

RESULT=$( ${1} -auto )

PSTRING="PIGLIT: {'result': 'pass'"
SSTRING="PIGLIT: {'result': 'skip'"
FSTRING="PIGLIT: {'result': 'fail'"

case $RESULT in
  *"$PSTRING"*) echo "${1}: pass";;

  *"$SSTRING"*) echo "${1}: skip";;
  
  *"$FSTRING"*) echo "${1}: fail";;

  *) echo "${1}: fail";;
esac
