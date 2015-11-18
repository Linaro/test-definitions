#!/system/bin/sh

scripts_dir="/system/bin/pm-qa"
test_func(){
   if [ ! -d "${scripts_dir}" ]; then
       echo "pm-qa=fail"
       exit
   fi

   cd "${scripts_dir}"

   pwd_dir=$PWD
   tests_dirs="cpuidle cpufreq cpuhotplug cputopology thermal"

   for dir in $tests_dirs; do
       var=$dir'_sanity.sh'
       subDir=${pwd_dir}/$dir
       if [ -d $subDir ]; then
           cd $subDir
       else
           continue
       fi

       /system/bin/sh $var
       if [ $? -ne 1 ]; then
           continue
       fi

       filelist=$(find . -name "*.sh" | sort)
       for file in $filelist; do
           path=$file
           /system/bin/sh $path
       done
       cd ..
   done

   # Find instances of cpuidle_killer and kill
   # all pids associated with it until a better
   # solution comes up.
   pids=$(pidof "cpuidle_killer")

   for pid in $pids; do
        kill -9 $pid
   done

   echo "pm-qa=pass"
}

test_func
exit
