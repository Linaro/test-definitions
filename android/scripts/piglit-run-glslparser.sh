#!/system/bin/sh

# find and loop over the vert and frag tests found
# looks recursively down the directory tree
export PIGLIT_PLATFORM=android
bin_path="/system/xbin/piglit/glslparsertest/glslparsertest"
data_dir="/data/piglit/glslparser/"
/system/bin/busybox find ${data_dir} -name "*.frag" -or -name "*.vert" -print0 | while read -d $'\0' file
do
   RESULTFOUND=$(grep expect_result ${file} )
   case $RESULTFOUND in
      *fail*) RESULTEXPECTED="fail";;
      *pass*) RESULTEXPECTED="pass";;
      *) RESULTEXPECTED="pass";;
   esac

   RESULT=$(${bin_path} ${file} $RESULTEXPECTED 1.00)

   PSTRING='PIGLIT: {"result": "pass"'
   SSTRING='PIGLIT: {"result": "skip"'
   FSTRING='PIGLIT: {"result": "fail"'

   case $RESULT in
      *"$PSTRING"*) echo "glslparser ${file}: pass";;
      *"$SSTRING"*) echo "glslparser ${file}: skip";;
      *"$FSTRING"*) echo "glslparser ${file}: fail";;
      *) echo "glslparser ${file}: fail";;
   esac
done
