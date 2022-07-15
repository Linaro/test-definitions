#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2022 Foundries.io Ltd.

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE

usage() {
    echo "Usage: $0 [-s <true|false>]" 1>&2
    exit 1
}

while getopts "s:" o; do
  case "$o" in
    s) SKIP_INSTALL="${OPTARG}" ;;
    *) usage ;;
  esac
done

# Install lamp and use systemctl for service management. Tested on Ubuntu 16.04,
# Debian 8, CentOS 7 and Fedora 24. systemctl should available on newer releases
# as well.
if [ "${SKIP_INSTALL}" = "True" ] || [ "${SKIP_INSTALL}" = "true" ]; then
    warn_msg "Dependencies installation skipped."
else
    dist_name
    # shellcheck disable=SC2154
    case "${dist}" in
      debian|ubuntu)
        pkgs="docker.io curl openssl"
        install_deps "${pkgs}"
        ;;
      centos|fedora)
        pkgs="docker curl openssl"
        install_deps "${pkgs}"
        ;;
      *)
        error_msg "Unsupported distribution!"
    esac
fi

! check_root && error_msg "You need to be root to run this script."
create_out_dir "${OUTPUT}"

# generate certificate
openssl genrsa -aes256 -passout pass:gsahdg -out server.pass.key 4096
check_return "openssl-generate-key-password"
openssl rsa -passin pass:gsahdg -in server.pass.key -out server.key
check_return "openssl-generate-key"
openssl req -new -key server.key -out server.csr -subj "/C=US/OU=Org/CN=localhost"
check_return "openssl-generate-csr"
openssl x509 -req -sha256 -days 365 -in server.csr -signkey server.key -out server.crt
check_return "openssl-generate-crt"

# build docker container
docker build --tag myhttpd .
check_return "build-httpd-container"

# start docker container
docker run --name myhttpd_curl -d -p 443:443 myhttpd
check_return "start-httpd-container"

# wait 15 seconds to allow container to fully start
sleep 15
# test curl
curl --cacert server.crt  --output index.html https://localhost
check_return "curl-get-self-signed-cert"

# stop docker
docker stop myhttpd_curl

# cleanup
rm server.pass.key
rm server.key
rm server.csr
rm server.crt
docker stop myhttpd_curl
