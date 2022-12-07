#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2021 Foundries.io Ltd.

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE
PTOOL="pkcs11-tool --module /usr/lib/libckteec.so.0.1.0"
USE_SE05X="True"
EXECUTE_LOOP="True"
TOKEN_LABEL=fio

usage() {
    echo "\
    Usage: $0 [-p <pkcs11-tool>] [-t <true|false>] [-s <true|false>] [-l <true|false>]

    -p <pkcs11-tool>
        pkcs11-tool with all the options required. Default is:
        pkcs11-tool --module /usr/lib/libckteec.so.0.1
    -t <true|false>
        This flag switches on/off the use of SE05X TPM device.
        It is turned on by default but users can choose to use
        softhsm as alternative. Setting this flag to False will
        prevent script from calling ssscli.
    -l <true|false>
        Run loop test. The test is meant to only be executed on
        SE05x device. Running this test with sofhsm might take
        a very long time and exhaust memory/storage on the device.
    -s <true|false>
        Skip install. True by default.
    "
}

while getopts "p:t:s:l:h" opts; do
    case "$opts" in
        p) PTOOL="${OPTARG}";;
        t) USE_SE05X="${OPTARG}";;
        s) SKIP_INSTALL="${OPTARG}";;
        l) EXECUTE_LOOP="${OPTARG}";;
        h|*) usage ; exit 1 ;;
    esac
done

! check_root && error_msg "You need to be root to run this script."
# Test run.
create_out_dir "${OUTPUT}"
install_deps "opensc openssl bc" "${SKIP_INSTALL}"

SO_PIN=12345678
PIN=87654321

se05x_cleanup()
{
    if [ "${USE_SE05X}" = "True" ] || [ "${USE_SE05X}" = "true" ]; then
        echo "Reset SE05x"
        ssscli se05x reset
    fi
}

se05x_connect()
{
    if [ "${USE_SE05X}" = "True" ] || [ "${USE_SE05X}" = "true" ]; then
        echo "Connect SE05x"
        ssscli connect se05x t1oi2c none
    fi
}

housekeeping()
{
    local ID="$1"
    local FILE_LIST=$@
    # remove ID from the file list
    unset FILE_LIST[0]

    echo "Cleanup"
    # shellcheck disable=SC2086
    $PTOOL --list-objects --pin "${PIN}"
    # shellcheck disable=SC2086
    $PTOOL -b  --type privkey --id "${ID}" --pin "${PIN}"
    # shellcheck disable=SC2086
    $PTOOL -b  --type pubkey --id "${ID}" --pin "${PIN}"
    # shellcheck disable=SC2086
    $PTOOL --list-objects --pin "${PIN}"

    for FILE in "${FILE_LIST}";
    do
        rm "${FILE}"
    done
}

test_cypher()
{
    local ID=01
    local cypher="$1"
    local mechanism="$2"
    FILE=hello
    se05x_connect

    echo "$cypher test"
    echo "Create $cypher keypair"
    # shellcheck disable=SC2086
    $PTOOL --keypairgen --key-type "${cypher}" --id "${ID}" --label ldts  --token-label fio --pin "${PIN}"
    check_return "$cypher-keypair"

    echo "Get the publick key to pubkey.spki"
    # shellcheck disable=SC2086
    $PTOOL -l --pin "${PIN}" --id "${ID}" --read-object --type pubkey --output-file pubkey.spki
    check_return "$cypher-pubkey-read"

    echo "hello world" > "${FILE}"

    echo "Create a digest sha256 : hello.hash"
    openssl dgst -binary -sha256 "${FILE}" > "${FILE}.hash"

    # The block below is used to make sure that
    # signing works for both ECC and RSA. In case of
    # ECC signing is done using SHA256 digest of the data
    # while in case of RSS signing is done using the data
    # itself.
    OPERATION="ec"
    INFILE="${FILE}.hash"
    if [ -z "${cypher##*RSA*}" ]; then
        OPERATION="rsa"
        INFILE="${FILE}"
    fi

    echo "Transform pubkey.spki from DER to PEM"
    openssl "${OPERATION}" -inform DER -outform PEM -in pubkey.spki -pubin > pubkey.pub

    echo "Sign hello.hash with the PEM key and generate hello.sig signature"
    # shellcheck disable=SC2086
    $PTOOL --sign --pin "${PIN}" --id "${ID}" --input-file "${INFILE}" --output-file "${FILE}.sig" --mechanism "${mechanism}" -f openssl

    echo "Use the public key to verify the file signature"
    openssl dgst -sha256 -verify pubkey.pub -signature "${FILE}.sig" "${FILE}"
    check_return "$cypher-pubkey-verify"

    housekeeping "${ID}" "${FILE}" "${FILE}.sig" "${FILE}.hash" pubkey.spki pubkey.pub
    se05x_cleanup
}

test_ecc_derive()
{
    se05x_connect
    # Alice id = 01
    # shellcheck disable=SC2086
    $PTOOL --keypairgen --key-type EC:prime256v1 --id 01 --label alice --token-label fio --pin "${PIN}"
    # shellcheck disable=SC2086
    $PTOOL --read-object --type pubkey --id 01 --token-label fio --pin "${PIN}" -o alice-pub.der
    # Bob    id = 02
    # shellcheck disable=SC2086
    $PTOOL --keypairgen --key-type EC:prime256v1 --id 02 --label bob --token-label fio --pin $PIN
    # shellcheck disable=SC2086
    $PTOOL --read-object --type pubkey --id 02 --token-label fio --pin "${PIN}" -o bob-pub.der
    echo "ECDH1-DERIVE"
    # shellcheck disable=SC2086
    $PTOOL --derive -m ECDH1-DERIVE --id 01 --label alice --token-label fio --pin "${PIN}" --input-file bob-pub.der --output-file bob.secret
    # shellcheck disable=SC2086
    $PTOOL --derive -m ECDH1-DERIVE --id 02 --label bob   --token-label fio --pin "${PIN}" --input-file alice-pub.der --output-file alice.secret
    echo "Diff secrets"
    diff bob.secret alice.secret
    check_return "ecc-pubkey-derive"

    housekeeping "${ID}" alice-pub.der alice.secret bob-pub.der bob.secret
    # shellcheck disable=SC2086
    $PTOOL -b --type privkey --id 02 --pin "${PIN}"
    # shellcheck disable=SC2086
    $PTOOL -b --type pubkey --id 02 --pin "${PIN}"
    # shellcheck disable=SC2086
    $PTOOL --list-objects --pin "${PIN}"
    se05x_cleanup
}

test_rsa_sign_verify()
{
    # test_rsa_sign_verify <mechanism> <hash>
    # test_rsa_sign_verify RSA-PKCS-PSS SHA256
    # HASH can be emtpy
    local ID=01
    local MECHANISM="$1"
    local HASH="$2"
    se05x_connect

    # Generate RSA keypair
    echo "Generate keypair 2048"
    # shellcheck disable=SC2086
    $PTOOL --pin "${PIN}" --keypairgen --key-type rsa:2048 --id "${ID}" --label rsa1 --token-label fio

    echo "Read object "
    # shellcheck disable=SC2086
    $PTOOL --pin "${PIN}" --read-object --type pubkey --id "${ID}" --token-label fio --output-file rsa-pubkey.der
    openssl rsa -inform DER -outform PEM -in rsa-pubkey.der -pubin > rsa-pubkey.pub

    echo "Creating data to sign"
    echo "data to sign (max 100 bytes)" > data

    echo "${MECHANISM} test sign/verify"
    if [ -n "${HASH}" ]; then
        openssl dgst -binary -sha256 data > data.hash
        # shellcheck disable=SC2086
        $PTOOL --pin "${PIN}" --salt-len=-1 --sign --id "${ID}" --token-label fio --hash-algorithm="${HASH}" --mechanism "${MECHANISM}" --input-file data.hash --output-file data.sig
        # shellcheck disable=SC2086
        $PTOOL --pin "${PIN}" --verify --salt-len=-1 --id "${ID}" --token-label fio --hash-algorithm=SHA256 --mechanism RSA-PKCS-PSS --input-file data.hash --signature-file data.sig | tee "${MECHANISM}-sign-verify.log"
        rm data.hash
    else
        # shellcheck disable=SC2086
        $PTOOL --pin "${PIN}" --sign --id "${ID}" --token-label fio --mechanism "${MECHANISM}" --input-file data --output-file data.sig
        # shellcheck disable=SC2086
        $PTOOL --pin "${PIN}" --verify --id "${ID}" --token-label fio --mechanism "${MECHANISM}" --input-file data --signature-file data.sig | tee "${MECHANISM}-sign-verify.log"
    fi
    grep "Signature is valid" "${MECHANISM}-sign-verify.log"
    check_return "${MECHANISM}-sign-verify"

    housekeeping "${ID}" data data.sig rsa-pubkey.der rsa-pubkey.pub "${MECHANISM}-sign-verify.log"
    se05x_cleanup
}

test_rsa_encrypt_decrypt()
{
    local ID=03
    se05x_connect

    echo "Creating data to sign"
    echo "data to sign (max 100 bytes)" > data

    # Generate RSA keypair
    echo "Generate keypair 2048"
    # shellcheck disable=SC2086
    $PTOOL --pin "${PIN}" --keypairgen --key-type rsa:2048 --id "${ID}" --label rsa1 --token-label fio

    echo "Read object "
    # shellcheck disable=SC2086
    $PTOOL --pin "${PIN}" --read-object --type pubkey --id "${ID}" --token-label fio --output-file rsa-pubkey.der
    openssl rsa -inform DER -outform PEM -in rsa-pubkey.der -pubin > rsa-pubkey.pub

    # Encrypt (RSA-PKCS)
    echo "RSA-PKCS Encrypt/decrypt"
    openssl rsautl -encrypt -inkey rsa-pubkey.pub -in data -pubin -out data.crypt
    # shellcheck disable=SC2086
    $PTOOL --pin "${PIN}" --decrypt --id "${ID}" --token-label fio --mechanism RSA-PKCS --input-file data.crypt > data.decrypted
    diff data data.decrypted
    check_return "rsa-encrypt-decrypt"

    housekeeping "${ID}" data data.crypt data.decrypt rsa-pubkey.der rsa-pubkey.pub
    se05x_cleanup
}

test_ec_sign_verify()
{
    local ID=02
    se05x_connect

    # Generate RSA keypair
    echo "Generate keypair EC:prime256v1"
    # shellcheck disable=SC2086
    $PTOOL --pin "${PIN}" --keypairgen --key-type EC:prime256v1 --id "${ID}" --label ec1 --token-label fio

    echo "Read object "
    # shellcheck disable=SC2086
    $PTOOL --pin "${PIN}" --read-object --type pubkey --id "${ID}" --token-label fio --output-file ec-pubkey.der
    openssl ec -inform DER -outform PEM -in ec-pubkey.der -pubin > ec-pubkey.pub

    echo "Creating data to sign"
    echo "data to sign (max 100 bytes)" > data

    # RSA-PKCS-PSS: test sign/verify
    echo "ECDSA-SHA256 test sign/verify"
    openssl dgst -binary -sha256 data > data.hash
    # shellcheck disable=SC2086
    $PTOOL --pin "${PIN}" --salt-len=-1 --sign --id "${ID}" --token-label fio --hash-algorithm=SHA256 --mechanism ECDSA-SHA256 --input-file data.hash --output-file data.sig
    # shellcheck disable=SC2086
    $PTOOL --pin "${PIN}" --verify --salt-len=-1 --id "${ID}" --token-label fio --hash-algorithm=SHA256 --mechanism ECDSA-SHA256 --input-file data.hash --signature-file data.sig | tee ECDSA-SHA256-sign-verify.log
    grep "Signature is valid" ECDSA-SHA256-sign-verify.log
    check_return "ECDSA-SHA256-sign-verify"
    rm data.hash
    rm data.sig

    # RSA-PKCS: test sign/verify
    echo "ECDSA test sign/verify"
    # shellcheck disable=SC2086
    $PTOOL --pin "${PIN}" --sign --id "${ID}" --token-label fio --mechanism ECDSA --input-file data --output-file data.sig
    # shellcheck disable=SC2086
    $PTOOL --pin "${PIN}" --verify --id "${ID}" --token-label fio --mechanism ECDSA --input-file data --signature-file data.sig | tee ECDSA-sign-verify.log
    grep "Signature is valid" ECDSA-sign-verify.log
    check_return "ECDSA-sign-verify"

    housekeeping "${ID}" data data.sig data.decrypt ec-pubkey.der ec-pubkey.pub ECDSA-SHA256-sign-verify.log ECDSA-sign-verify.log
    se05x_cleanup
}

test_import_key() {
    se05x_connect
    if [ "${USE_SE05X}" = "True" ] || [ "${USE_SE05X}" = "true" ]; then
        OID=$(ssscli se05x readidlist | grep RSA_CRT | grep "Key Pair" | head -n 1 | awk '{print substr($2,3)}')
        ID=05
        # shellcheck disable=SC2086
        $PTOOL --keypairgen --key-type RSA:4096 --id "${ID}" --label "SE_${OID}" --token-label fio --pin "${PIN}"
        NUM_KEYS=$($PTOOL --list-objects --pin "${PIN}" | grep -c "SE_${OID}")
        if [ "${NUM_KEYS}" -eq "2" ]; then
            report_pass "se05x-import-keys"
        else
            report_fail "se05x-import-keys"
        fi
        echo "Cleanup temporary certificates"
        housekeeping "${ID}"
    else
        report_skip "se05x-import-keys"
    fi
}

test_rsa_loop()
{
    se05x_connect
    BREAK="False"
    LABEL=0
    while [ "$BREAK" = "False" ]
    do
        # generate RSA:1024 certificate pairs until there is no
        # more space to keep them.
        # shellcheck disable=SC2086
        LABEL=$((LABEL+1))
        pipe0_status "$PTOOL --keypairgen --key-type RSA:1024 --label ${LABEL} --id 33 --token-label fio --pin ${PIN} 2>&1" "tee ${LABEL}.log"
        test_status=$?
        if [ "${test_status}" -ne 0 ]; then
            if grep "CKR_DEVICE_MEMORY" "${LABEL}.log"; then
                # If this test fails, remaining results may be tainted
                # TA is unlikely to recover from OOM situation
                echo "Out of memory"
                report_fail "rsa-loop-key-create-memory"
            else
                report_pass "rsa-loop-key-create-memory"
            fi
            break
        fi
    done
    NUM_CERTS=$($PTOOL --list-objects --token-label fio --pin "${PIN}" | grep ID | grep -c 33)
    echo "Found ${NUM_CERTS} certificates with ID=33"
    EXPECTED=$(echo "${LABEL}*2" | bc)
    if [ "${NUM_CERTS}" = "${EXPECTED}" ]; then
        report_pass "rsa-loop-key-create"
    else
        echo "Expected ${EXPECTED} keys, found ${NUM_CERTS}"
        report_fail "rsa-loop-key-create"
    fi

    if [ "${NUM_CERTS}" -ne "0" ]; then
        # remove all certificates
        LOOPS=$(echo "${NUM_CERTS}/2-1" | bc)
        for a in $(seq 0 "${LOOPS}")
        do
            echo "Removing ${a} cert pair"
            # shellcheck disable=SC2086
            $PTOOL -b --type privkey --id 33 --pin "${PIN}"
            # shellcheck disable=SC2086
            $PTOOL -b --type pubkey --id 33 --pin "${PIN}"
        done
    fi
    NUM_CERTS=$($PTOOL --list-objects --token-label fio --pin "${PIN}" | grep ID | grep -c 33)
    if [ "${NUM_CERTS}" -ne "0" ]; then
        report_fail "rsa-loop-remove-certs"
    else
        report_pass "rsa-loop-remove-certs"
    fi

    se05x_cleanup
}

if [ "${USE_SE05X}" = "True" ] || [ "${USE_SE05X}" = "true" ]; then
    ssscli connect se05x t1oi2c none
    check_return "ssscli-connect"
else
    report_skip "ssscli-connect"
fi
# shellcheck disable=SC2086
$PTOOL --init-token --label "${TOKEN_LABEL}" --so-pin "${SO_PIN}"
check_return "pkcs11-init-token"
# shellcheck disable=SC2086
$PTOOL --init-pin --token-label "${TOKEN_LABEL}" --so-pin "${SO_PIN}" --pin "${PIN}"
check_return "pkcs11-init-pin"
# shellcheck disable=SC2086
$PTOOL --list-mechanisms --token-label "${TOKEN_LABEL}" --pin "${PIN}"
check_return "pkcs11-list-mechanisms"
# shellcheck disable=SC2086
$PTOOL --list-objects --token-label "${TOKEN_LABEL}" --pin "${PIN}"
check_return "pkcs11-list-objects"

if [ "${USE_SE05X}" = "True" ] || [ "${USE_SE05X}" = "true" ]; then
    ssscli disconnect
    check_return "ssscli-disconnect"
else
    report_skip "ssscli-disconnect"
fi

test_cypher "EC:prime256v1" "ECDSA"
test_cypher "RSA:2048" "SHA256-RSA-PKCS"
test_cypher "RSA:4096" "SHA256-RSA-PKCS"
test_ecc_derive
test_rsa_sign_verify RSA-PKCS-PSS SHA256
test_rsa_sign_verify RSA-PKCS
test_rsa_sign_verify SHA256-RSA-PKCS
test_rsa_encrypt_decrypt
test_ec_sign_verify
test_import_key
if [ "${EXECUTE_LOOP}" = "True" ] || [ "${EXECUTE_LOOP}" = "true" ]; then
    test_rsa_loop
else
    report_skip "rsa-loop-remove-certs"
fi

exit 0
