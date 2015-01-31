#!/system/bin/sh

scripts_dir="/system/bin/pm-qa"
test_func(){
   if [ ! -d "${scripts_dir}" ]; then
       echo "pm-qa=fail"
       exit
   fi

   bin_dir="/data/bin"

   if [ ! -d $bin_dir ]; then
        mkdir $bin_dir
   fi

   cd ${bin_dir}

   export PATH=${bin_dir}:$PATH

   cd "${scripts_dir}"

   pwd_dir=$PWD
   echo $pwd
   tests_dirs="cpuidle cpufreq cpuhotplug cputopology thermal"

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
       if [ $? -ne 1 ]; then
           continue
       fi

       for file in `find . -name "*.sh" | sort`; do
           path=$file
           echo $path
           /system/bin/sh $path
       done
       cd ..
   done

   echo "pm-qa=pass"
}

test_func
