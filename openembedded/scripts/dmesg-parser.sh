#!/bin/sh

TMP_LOG="log.txt"

parse_locking_api() {
    cat $1 | grep "|$" | sed 's/^[][ 0-9\.]*//' | awk '
    /^\|/ {
        FS=":"
        split($0, l, "|"); j=1;
        for(i=1;i<=NF;i++) {
            if(length(l[i]) > 0)
                lock[j++] = l[i]
        }
    }

    /:[ a-z\|]*\|$/ {
        ptr=1; k=1;
        for(i=1;i<length($2);i+=ptr) {
            result=substr($2, i, length(lock[k]))
            if(result ~ /[^ ]+/) {
                extra_info=""
                if(result=="failed") {
                    result="ok"
                    extra_info=" [expected failed]"
                }
                printf("%s(%s)%s: %s\n", $1, lock[k], extra_info, result)
            }
            ptr=length(lock[k])+1
            k++
        }
    }'
}

parse_cpu_write_buffer_testing() {
    KEY="Testing write buffer coherency"
    log=`cat $1 | grep "${KEY}"`
    [ -z "${log}" ] && return 0
    t_id=${log%:*}
    t_r=${log##*:}
    f_reason=${t_r#*, }
    if [ "${f_reason}" != "${t_r}" ]; then
        t_r="FAILED"
        t_id="${t_id} [${f_reason}]"
    fi
    echo "${t_id}: ${t_r}"
}

parse_ring_buffer_test_result () {
    KEY="Running ring buffer tests"
    [ -z "`cat $1 | grep \"${KEY}\"`" ] && return
    if [ -n "`cat $1 | grep 'Ring buffer PASSED!'`" ] ; then
        echo "Ring buffer test: ok"
    else
        echo "Ring buffer test: failed"
    fi
}

parse_event_trace_test () {
    grep "^Testing " $1 | while read l;
    do
        t_id=${l%:*}
        t_r=${l##*: }
        [ -n "`echo ${t_r}|grep \".* PASSED\"`" ] && t_id="${t_id} ${t_r% PASSED}" && t_r="PASSED"
        [ -n "${t_r}" ] && case ${t_r} in
            Enabled* )
                t_id="${t_id} [${t_r}]"
                t_r="skip"
                ;;
            error* )
                t_id="${t_id} [${t_r}]"
                t_r="FAILED"
                ;;
            "OK" | "PASSED" | "ret = 0" )
                t_r="ok"
                ;;
            * )
                t_id="${t_id} [${t_r}]"
                t_r="FAILED"
                ;;
        esac
        [ -n "${t_id}" -a -n "${t_r}" ] && echo "${t_id}: ${t_r}"
    done
}

parse_test_string_helper () {
    KEY="test_string_helpers: Running tests"
    [ -z "`cat $1 | grep \"${KEY}\"`" ] && return
    if [ -n "`cat $1 | grep 'Test failed: flags'`" ] ; then
        echo "test_string_helpers: failed"
    else
        echo "test_string_helpers: ok"
    fi
}

parse_odebug_test () {
    grep "ODEBUG: selftest" $1 | while read l;
    do
        case "${l}" in
            "ODEBUG: selftest passed" )
                echo "ODEBUG selftest: ok"
                ;;
            * )
                echo "ODEBUG [${l#ODEBUG: }]: failed"
                ;;
        esac
    done
}

parse_rt_mutex_test () {
    r="`grep "Initializing RT-Tester" $1`"
    [ -n "${r}" ] && echo "${r}" | tr '[:upper:]' '[:lower:]'
}

cat $1 | sed 's/^[][ 0-9\.]*//' > ${TMP_LOG}

parse_locking_api ${TMP_LOG}
parse_cpu_write_buffer_testing ${TMP_LOG}
parse_ring_buffer_test_result ${TMP_LOG}
parse_event_trace_test ${TMP_LOG}
parse_test_string_helper ${TMP_LOG}
parse_odebug_test ${TMP_LOG}
parse_rt_mutex_test ${TMP_LOG}
