#!/bin/bash

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"


# $1=Certificate Name; $2=AppCert/Private Key; $3=CA Cert Name
deployAppSecret() {
    echo $1
    kubectl create -n development secret generic $1-tls --from-file=$DIR/$2_key.pem --from-file=$DIR/$2_cert_chain.pem --from-file=$DIR/$3.pem
}

main() {
    kubectl create ns development
    # echoserver App
    deployAppSecret "echoserver-ca1" "echoserver" "ca_1_cert"
    deployAppSecret "echoserver-ca1-ca2" "echoserver" "ca_1_ca_2_bundle"
    # echoserver uk App
    deployAppSecret "echoserver-uk" "echoserver-uk" "ca_1_cert"
    # echoserver canada App
    deployAppSecret "echoserver-canada" "echoserver-canada" "ca_1_cert"
}

main $@
