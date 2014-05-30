#!/system/bin/sh

# find and loop over the shader tests found
# recursively in the named directory

find ${2} -name *.shader_test -print0 | while read -d $'\0' file
do
   RESULT=$( ${1} ${file} -auto )

   PSTRING="PIGLIT: {'result': 'pass'"
   SSTRING="PIGLIT: {'result': 'skip'"
   FSTRING="PIGLIT: {'result': 'fail'"

   case $RESULT in
     *"$PSTRING"*) echo "${file}: pass";;

     *"$SSTRING"*) echo "${file}: skip";;
  
     *"$FSTRING"*) echo "${file}: fail";;

     *) echo "${file}: fail";;
   esac
done
