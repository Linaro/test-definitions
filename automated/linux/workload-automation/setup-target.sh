#!/bin/sh -e

TEST_DIR=$(dirname "$(realpath "$0")")
OUTPUT="${TEST_DIR}/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE

# shellcheck disable=SC1090
. "${TEST_DIR}/../../lib/sh-test-lib"

if [ -n "$1" ]; then
    SKIP_INSTALL="$1"
else
    SKIP_INSTALL="false"
fi
install_deps "openssh-client openssh-server sshpass" "${SKIP_INSTALL}"

# Enable root login with password.
sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
grep "PermitRootLogin yes" /etc/ssh/sshd_config

# Change root password to "linaro123".
echo "root:linaro123" | chpasswd

/etc/init.d/ssh restart && sleep 3
report_pass "setup-root-password-login"
