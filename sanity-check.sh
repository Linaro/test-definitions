#!/bin/sh
set -ex

python3 validate.py \
    -r build-error.txt \
    -p E501 W503 \
    -s SC1091 SC2230

# pycodestyle checks skipped:
# E510: line too long

# Shellchecks skipped:
# SC1091: not following

# Reason: 'which' is widely used and supported. And 'command' applets isn't
# available in busybox, refer to https://busybox.net/downloads/BusyBox.html
# SC2230: which is non-standard. Use builtin 'command -v' instead.
