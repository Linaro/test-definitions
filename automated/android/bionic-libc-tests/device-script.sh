#!/bin/sh

OUTPUT_FILE="/data/local/tmp/result.txt"

TESTS=
TESTS="${TESTS} test_dlclose_destruction test_dlopen_null test_executable_destructor"
TESTS="${TESTS} test_getaddrinfo test_getgrouplist test_gethostbyname test_gethostname"
TESTS="${TESTS} test_mutex test_netinet_icmp test_pthread_cond test_pthread_mutex"
TESTS="${TESTS} test_pthread_once test_pthread_rwlock test_relocs test_setjmp"
TESTS="${TESTS} test_seteuid test_static_cpp_mutex test_static_executable_destructor"
TESTS="${TESTS} test_static_init test_sysconf test_udp"

for TEST in $TESTS; do
    if [ ! -f "/system/bin/${TEST}" ]; then
        continue
    fi
    $TEST
    EXIT_STATUS=$?
    if [ $EXIT_STATUS -ne 0 ]; then
        echo "$TEST fail" >> ${OUTPUT_FILE}
    else
        echo "$TEST pass" >> ${OUTPUT_FILE}
    fi
done
