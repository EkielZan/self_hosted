#!/usr/bin/env bash
#
# Usage: dev_signed_cert.sh HOSTNAME
#
# Creates a CA cert and then generates an SSL certificate signed by that CA for the
# given hostname.
#
# After running this, add the generated dev_cert_ca.cert.pem to the trusted root
# authorities in your browser / client system.
#

# set -x

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
NAME=${1:-localhost}
CADIR=/home/ca/ca

CA_KEY=$CADIR/rootCA.key

[ -f $CA_KEY ] || openssl genrsa -des3 -out $CA_KEY 2048

CA_CERT=$CADIR/rootCA.pem

[ -f $CA_CERT ] || openssl req -x509 -new -nodes -key $CA_KEY -sha256 -days 365 -out $CA_CERT

mkdir ${NAME}

HOST_KEY=$DIR/${NAME}/$NAME.key.pem

[ -f $HOST_KEY ] || openssl genrsa -out $HOST_KEY 2048

HOST_CERT=$DIR/${NAME}/$NAME.cert.pem

if ! [ -f $HOST_CERT ] ; then
    HOST_CSR=$DIR/${NAME}/$NAME.csr.pem
    [ -f $HOST_CSR ] || openssl req -new -key $HOST_KEY -out $HOST_CSR -config req.cnf
    HOST_EXT=$DIR/${NAME}/$NAME.ext
    echo >$HOST_EXT
    echo >>$HOST_EXT authorityKeyIdentifier=keyid,issuer
    echo >>$HOST_EXT basicConstraints=CA:FALSE
    echo >>$HOST_EXT keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
    echo >>$HOST_EXT subjectAltName = @alt_names
    echo >>$HOST_EXT
    echo >>$HOST_EXT [alt_names]

    NAME_N=1
    IP_IN=1
    for ALT_NAME in $(cat dns_list) ; do
	if [[ "$ALT_NAME" =~ [A-Za-z] ]]; then
	   echo DNS = $ALT_NAME
           echo >>$HOST_EXT DNS.$NAME_N = $ALT_NAME
           NAME_N=$(( NAME_N + 1 ))
        else
	   echo IP = $ALT_NAME
           echo >>$HOST_EXT IP.$IP_IN = $ALT_NAME
           IP_IN=$(( IP_IN + 1 ))
	fi
    done
    echo "Generate certificate"
    openssl x509 -req -in $HOST_CSR -CA $CA_CERT -CAkey $CA_KEY -CAcreateserial \
        -out $HOST_CERT -days 365 -sha256 -extfile $HOST_EXT 

#    rm $HOST_EXT
fi


