#!/bin/bash

output=$(/usr/share/bcc/tools/cpuunclaimed 1 5 2>&1)
status=$?

echo $output
echo $status

if [ $status -ne 0 ]; then
    echo "Command failed with exit status $status" >&2
    lava-test-case "bpf-test" --result "fail"
    exit 1
fi

IFS=$'\n' read -rd '' -a lines <<< "$output"
if [ ${#lines[@]} -ne 6 ]; then
    echo "Expected 6 lines, got ${#lines[@]}" >&2
    lava-test-case "bpf-test" --result "fail"
    exit 1
fi

# Verify line contents
if [ "${lines[0]}" != "Sampling run queues... Output every 1 seconds. Hit Ctrl-C to end." ]; then
    echo "Unexpected first line: ${lines[0]}" >&2
    lava-test-case "bpf-test" --result "fail"
    exit 1
fi

for i in {1..5}; do
    if [[ "${lines[$i]}" != *"%CPU"* ]]; then
        echo "Line $((i+1)) missing %CPU: ${lines[$i]}" >&2
	lava-test-case "bpf-test" --result "fail"
        exit 1
    fi
done

if [ -n "${lines[6]}" ]; then
    echo "Expected empty line 7, got: ${lines[6]}" >&2
    lava-test-case "bpf-test" --result "fail"
    exit 1
fi

lava-test-case "bpf-test" --result "pass"
exit 0
