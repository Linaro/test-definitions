#!/usr/bin/awk
started && /### dt-test ### end of selftest/ {
    sub(/,/, "", $11)
    printf "DT-SELFTEST %s: %s\n", $11, $10
    printf "DT-SELFTEST %s: %s\n", $13, $12
    print "dt-selftest end"
    exit
}

!started && /### dt-test ### start of selftest/ {
    print "dt-selftest start"
    started = 1
}
