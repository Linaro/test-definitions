#!/bin/sh
#
# openssl-bsaes.sh - test the NEON bit sliced AES implementation in various sizes and modes
#
# Copyright (C) 2010 - 2014, Linaro Limited.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# Author: Ard Biesheuvel <ard.biesheuvel@linaro.org> 2013-07-09

set -u

BITS=$1
MODE=$2

exec 2> /dev/null

KEY=$(dd if=/dev/urandom bs=32 count=1 | hexdump -ve '/1 "%02x"')
ALG=aes-$BITS-$MODE
NAME=neon-$ALG

# ctr mode is essentially a stream cipher, so instead of using it for both
# encrypt and decrypt (which both call encrypt() under the hood), disable NEON
# for the decrypt case by setting OPENSSL_armcap to zero in the environment
if [ "$MODE" = "ctr" ]
then
    ARMCAP="env OPENSSL_armcap=0"
fi

TMP=/tmp/bsaestest-$$.md5sum

export KEY
export ARMCAP

for i in $(seq 100)
do
    TMPFIFO=mktemp
    mkfifo $TMPFIFO
    touch $TMP
    md5sum $TMPFIFO | awk '{ print $1 }' > $TMP &
    OUT=$(dd if=/dev/urandom bs=65 count=$i |
    tee $TMPFIFO |
    openssl enc -$ALG -pass env:KEY |
    ${ARMCAP:-} openssl enc -d -$ALG -pass env:KEY |
    md5sum | awk '{ print $1 }' )
    while [ "x$OUT" = "x" ] || [ "x$(cat $TMP)" = "x" ]
    do
        :
    done
    rm $TMPFIFO
    if [ "$OUT" != "$(cat $TMP)" ]
    then
        echo ${NAME}: fail
        rm -f $TMP
        exit 1
    fi
done

rm -f $TMP
echo ${NAME}: pass
