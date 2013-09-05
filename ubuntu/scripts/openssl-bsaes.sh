#!/bin/bash

##
## openssl-bsaes.sh - test the NEON bit sliced AES implementation
##                    in various sizes and modes
##
## 2013-07-09 Ard Biesheuvel <ard.biesheuvel@linaro.org>
##

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
if [ "$MODE" == "ctr" ]
then
	ARMCAP="env OPENSSL_armcap=0"
fi

TMP=/tmp/bsaestest-$$.md5sum

export KEY
export ARMCAP

for i in $(seq 100)
do
	OUT=$(dd if=/dev/urandom bs=65 count=$i |
		tee >(md5sum >$TMP) |
		openssl enc -$ALG -pass env:KEY |
		${ARMCAP:-} openssl enc -d -$ALG -pass env:KEY |
		md5sum)

	if [ "$OUT" != "$(cat $TMP)" ]
	then
		echo ${NAME}: fail
		rm -f $TMP
		exit 1
	fi
done

rm -f $TMP
echo ${NAME}: pass
