#!/bin/bash
info_log ()
{
    echo -e "\033[32m=====> INFO: ${1}\033[0m"
}
warn_log ()
{
    echo -e "\033[33m=====> WARN: ${1}\033[0m"
}
error_log ()
{
    echo -e "\033[31m=====> ERROR: ${1}\033[0m"
}
set_orderer_globals ()
{
    ORG="${FABRIC_CFG_PATH}/crypto-config/ordererOrganizations/orderers.com"
    export ORDERER_ADDR='orderer0.orderers.com:7050'
    export ORDERER_CA="${ORG}/orderers/orderer0.orderers.com/msp/tlscacerts/tlsca.orderers.com-cert.pem"

    export CORE_PEER_LOCALMSPID='orderersMSP'
    export CORE_PEER_MSPCONFIGPATH="${ORG}/users/Admin@orderers.com/msp"
    export CORE_PEER_TLS_ROOTCERT_FILE=${ORDERER_CA}
}
set_peer_globals ()
{
	ORG="${FABRIC_CFG_PATH}/crypto-config/peerOrganizations/${org}.com"
	export CORE_PEER_LOCALMSPID="${org}MSP"
	export CORE_PEER_ADDRESS="${peer}.${org}.com:7051"
	export CORE_PEER_MSPCONFIGPATH="${ORG}/users/Admin@${org}.com/msp"
	export CORE_PEER_TLS_KEY_FILE="${ORG}/peers/${peer}.${org}.com/tls/server.key"
    export CORE_PEER_TLS_CERT_FILE="${ORG}/peers/${peer}.${org}.com/tls/server.crt"
	export CORE_PEER_TLS_ROOTCERT_FILE="${ORG}/peers/${peer}.${org}.com/tls/ca.crt"
}