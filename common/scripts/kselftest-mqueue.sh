#!/bin/sh

cd $(dirname $0)
BASEDIR=$(pwd)
LAVA_ROOT="${BASEDIR}/../.."
TEST_DIR="${LAVA_ROOT}/kselftest/mqueue"

#### Test mq_open_tests ########
echo
echo "Test mq_open_tests"
echo
cd ${TEST_DIR}
gcc -O2 mq_open_tests.c -o mq_open_tests -lrt
./mq_open_tests /test1 || echo "mq_open_tests: FAIL"

#### Test mq_perf_tests ########
echo
echo "Test mq_perf_tests"
echo
#   Build libpopt
cd ${LAVA_ROOT}
wget http://rpm5.org/files/popt/popt-1.16.tar.gz -O - | tar zxf -
cd popt-1.16
#   Due to the config.guess doesn't support aarch64 yet. We have to specify system type
[ `uname -m` = "aarch64" ] && BUILD="--build=aarch64-unknown-linux-gnu"
./configure ${BUILD} --prefix=/usr
make install
cd ${TEST_DIR}
gcc -O2 -o mq_perf_tests mq_perf_tests.c -lrt -lpthread -lpopt
./mq_perf_tests || echo "mq_perf_tests: FAIL"

