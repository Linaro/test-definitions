#!/bin/sh
set -ex

python3 validate.py \
    -r build-error.txt \
    -p E501 W503 E203 \
    -s SC1091 SC2230 SC3043 \
    -l warning

# pycodestyle checks skipped:
# E501: line too long
# E203: Whitespace before ':'
#   Disabled because conflicting with black, refer to the link for details
#   https://black.readthedocs.io/en/stable/the_black_code_style/current_style.html#slices

# Shellchecks skipped:
# SC1091: not following

# Reason: 'which' is widely used and supported. And 'command' applets isn't
# available in busybox, refer to https://busybox.net/downloads/BusyBox.html
# SC2230: which is non-standard. Use builtin 'command -v' instead.

# "warning" is the default severity level for shellcheck
