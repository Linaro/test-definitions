#!/bin/bash

output=$(/usr/share/bcc/tools/cpuunclaimed 0.3 5 2>&1)
status=$?

echo $output
echo $status

if [ $status -ne 0 ]; then
    echo "Command failed with exit status $status" >&2
    lava-test-case "bpf-test" --result "fail"
    exit 1
fi

IFS=$'\n' read -rd '' -a lines <<< "$output"

# Verify line contents
if [ "${lines[0]}" != "Sampling run queues... Output every 0.3 seconds. Hit Ctrl-C to end." ]; then
    echo "Unexpected first line: ${lines[0]}" >&2
    lava-test-case "bpf-test" --result "fail"
    exit 1
fi

lava-test-case "bpf-test" --result "pass"
exit 0
