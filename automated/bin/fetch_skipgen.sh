#!/bin/sh
set -e

# Retrieve a given version of skipgen from
# https://github.com/Linaro/skipgen/releases and copy to the
# arm64/armeabi/x86_64/i386 directories.

if [ -z "$1" ]; then
    echo "Usage: ${0} <skipgen_version_number>"
    echo "For example:"
    echo "    ${0} 0.2.1"
    echo ""
    echo "Be sure to not include the leaving 'v'."
    echo ""
    exit 1
fi

SKIPGEN_VERSION=$1
ROOT_PATH=$(dirname "$0")
ARCHS="arm64 armeabi x86_64 i386"

for arch in ${ARCHS}; do

    # Translate test-definition arch names to skipgen arch names
    skipgen_arch=""
    case ${arch} in
        arm64)
            skipgen_arch="arm64"
            ;;
        armeabi)
            skipgen_arch="armv7"
            ;;
        x86_64)
            skipgen_arch="amd64"
            ;;
        i386)
            skipgen_arch="386"
            ;;
        *)
            echo "Unknown architecture ${arch}"
            exit 1
            ;;
    esac

    # Fetch tar file, save in /tmp
    wget -O "/tmp/skipgen_${SKIPGEN_VERSION}_linux_${skipgen_arch}.tar.gz" \
        "https://github.com/Linaro/skipgen/releases/download/v${SKIPGEN_VERSION}/skipgen_${SKIPGEN_VERSION}_linux_${skipgen_arch}.tar.gz"
    # Extract skipgen binary from tar, save in the local arch folder
    tar xvzf "/tmp/skipgen_${SKIPGEN_VERSION}_linux_${skipgen_arch}.tar.gz" -C "${ROOT_PATH}/${arch}/" skipgen
    # Remove tmp file
    rm -f "/tmp/skipgen_${SKIPGEN_VERSION}_linux_${skipgen_arch}.tar.gz"

done
