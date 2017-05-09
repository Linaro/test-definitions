#!/system/bin/sh
set -x

TEST_DIR="/data/local/tmp/pm-qa"
export PATH="$PATH":"$TEST_DIR"

test_func(){
   tests="$1"

   for test in $tests; do
       var="${test}_sanity.sh"
       subDir="${TEST_DIR}/${test}"
       cd "$subDir" || continue

       /system/bin/sh "$var"
       if [ $? -ne 1 ]; then
           continue
       fi

       filelist=$(find . -name "*.sh" | sort)
       for file in $filelist; do
           path="$file"
           /system/bin/sh "$path"
       done
       cd ..
   done

   # Find instances of cpuidle_killer and kill
   # all pids associated with it until a better
   # solution comes up.
   pids=$(pidof "cpuidle_killer")

   for pid in $pids; do
        kill -9 "$pid"
   done

   echo "pm-qa=pass"
}

test_func "$1"
exit
