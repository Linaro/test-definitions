#!/bin/sh -ex

TEST_DIR=$(dirname "$(realpath "$0")")
# shellcheck disable=SC1090
. "${TEST_DIR}/../../lib/sh-test-lib"

# On unsupported distros, installation will be skipped by default.
install_deps openssh-server

# Add id_rsa.pub key sent by host to authorized_keys.
pub_key=$(grep "pub_key" /tmp/lava_multi_node_cache.txt | awk -F"=" '{print $NF}')
mkdir -p ~/.ssh/
echo "ssh-rsa ${pub_key} fuego-lava" > ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# Enabled root login.
if ! grep "^PermitRootLogin yes" /etc/ssh/sshd_config; then
    # Enable root login.
    sed -i 's/^# *PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
    sed -i 's/^ *PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config

    # Restart ssh.
    dist_name
    # shellcheck disable=SC2154
    case "${dist}" in
        debian|ubuntu|fedora|centos)
            systemctl restart ssh
            systemctl status ssh
            ;;
        *)
            warning_msg "Unknown distro: ${dist}, attempting to restart ssh..."
            /etc/init.d/ssh restart || true
            service ssh restart || true
            ;;
    esac
    sleep 3
fi

