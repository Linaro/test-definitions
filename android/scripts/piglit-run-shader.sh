#!/system/bin/sh

# find and loop over the shader tests found
# recursively in the named directory

export PIGLIT_PLATFORM=android
bin_path="/system/xbin/piglit/piglit-shader-test/shader_runner"
data_dir="/data/piglit/shader"
glsl_es1_data_dir="${data_dir}/glsl-es-1.00/"
glsl_es3_data_dir="${data_dir}/glsl-es-3.00/"

/system/bin/busybox find ${data_dir} -name *.shader_test -print0 | while read -d $'\0' file
do
   RESULT=$(${bin_path} ${file} -auto )

   PSTRING='PIGLIT: {"result": "pass"'
   SSTRING='PIGLIT: {"result": "skip"'
   FSTRING='PIGLIT: {"result": "fail"'

   case $RESULT in
     *"$PSTRING"*) echo "${file}: pass";;

     *"$SSTRING"*) echo "${file}: skip";;
  
     *"$FSTRING"*) echo "${file}: fail";;

     *) echo "${file}: fail";;
   esac
done
