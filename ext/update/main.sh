#!/bin/bash
: <<'COMMIT'
CHANNEL_NAME
FABRIC_CFG_PATH
COMMIT
apt -y update
apt -y install jq
set -e
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
echo
echo " ____    _____      _      ____    _____ "
echo "/ ___|  |_   _|    / \    |  _ \  |_   _|"
echo "\___ \    | |     / _ \   | |_) |   | |  "
echo " ___) |   | |    / ___ \  |  _ <    | |  "
echo "|____/    |_|   /_/   \_\ |_| \_\   |_|  "
echo
echo "Extend your first network (EYFN) test"
echo
set_orderer_globals
pushd ${FABRIC_CFG_PATH}/channel-artifacts
    info_log "Fetching the most recent channel configuration block, decoding to JSON and isolating config to original_config.json"
        peer channel fetch config config_block.pb -o ${ORDERER_ADDR} -c ${CHANNEL_NAME} --tls --cafile ${ORDERER_CA}
        configtxlator proto_decode --input config_block.pb --type common.Block | jq .data.data[0].payload.data.config > original_config.json
    info_log "Modify the configuration to append the new org"
        jq -s '.[0] * {"channel_group":{"groups":{"Application":{"groups": {"extMSP":.[1]}}}}}' original_config.json ext.json > modified_config.json
    info_log "Compute a config update, based on the differences between original_config.json and modified_config.json"
        configtxlator proto_encode --input original_config.json --type common.Config >original_config.pb
        configtxlator proto_encode --input modified_config.json --type common.Config >modified_config.pb
        configtxlator compute_update --channel_id ${CHANNEL_NAME} --original original_config.pb --updated modified_config.pb >config_update.pb
    info_log "Write config_update.pb as a transaction to ext_update_in_envelope.pb"
        configtxlator proto_decode --input config_update.pb --type common.ConfigUpdate >config_update.json
        echo '{"payload":{"header":{"channel_header":{"channel_id":"'${CHANNEL_NAME}'", "type":2}},"data":{"config_update":'$(cat config_update.json)'}}}' | jq . >config_update_in_envelope.json
        configtxlator proto_encode --input config_update_in_envelope.json --type common.Envelope >ext_update_in_envelope.pb
    info_log "Signing config transaction to add org to network created"
    (
        org=zjhl;peer=peer0;set_peer_globals
        peer channel signconfigtx -f ext_update_in_envelope.pb
    )
    info_log "Submitting transaction from a different peer which also signs it"
    (
        org=zjhl;peer=peer1;set_peer_globals
        peer channel update -f ext_update_in_envelope.pb -c ${CHANNEL_NAME} -o ${ORDERER_ADDR} --tls --cafile ${ORDERER_CA}
    )
popd
echo
echo "========= All GOOD, EYFN test execution completed =========== "
echo
echo " _____   _   _   ____   "
echo "| ____| | \ | | |  _ \  "
echo "|  _|   |  \| | | | | | "
echo "| |___  | |\  | | |_| | "
echo "|_____| |_| \_| |____/  "
echo