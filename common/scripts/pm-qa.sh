#!/system/bin/sh

scripts_dir="/data/benchmark/pm-qa"
test_func(){
   if [ ! -d "${scripts_dir}" ]; then
       echo "pm-qa=fail"
       exit
   fi

   mkdir /data/bin/
   cd /data/bin

   busybox ln -s -f /system/bin/busybox awk
   busybox ln -s -f /system/bin/busybox basename
   busybox ln -s -f /system/bin/busybox chmod
   busybox ln -s -f /system/bin/busybox chown
   busybox ln -s -f /system/bin/busybox cp
   busybox ln -s -f /system/bin/busybox diff
   busybox ln -s -f /system/bin/busybox find
   busybox ln -s -f /system/bin/busybox grep
   busybox ln -s -f /system/bin/busybox rm
   busybox ln -s -f /system/bin/busybox seq
   busybox ln -s -f /system/bin/busybox taskset
   busybox ln -s -f /system/bin/busybox tee
   busybox ln -s -f /system/bin/busybox printf
   busybox ln -s -f /system/bin/busybox wc

   busybox ln -s -f /system/bin/fake_command command
   busybox ln -s -f /system/bin/fake_sudo sudo
   busybox ln -s -f /system/bin/fake_udevadm udevadm

   export PATH=/data/bin:$PATH

   cd "${scripts_dir}"

   pwd_dir=$PWD
   echo $pwd
   tests_dirs="cpuidle cpufreq cpuhotplug suspend thermal"

   for dir in $tests_dirs; do
       var=$dir'_sanity.sh'
       subDir=${pwd_dir}/$dir
       if [ -d $subDir ]; then
           cd $subDir
       else
           continue
       fi

       echo `pwd`

       /system/bin/sh $var
       if [ $? -ne 0 ]; then
           continue
       fi

       for file in `find . -name "*.sh"`; do
           path=$file
           echo $path
           /system/bin/sh $path
       done
       cd ..
   done

   echo "pm-qa=pass"
}

test_func
