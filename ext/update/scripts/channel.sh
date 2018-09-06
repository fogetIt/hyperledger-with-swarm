#!/bin/bash
source utils.sh
: <<'COMMIT'
SLEEP_DELAY
ORDERER_CA
ORDERER_ADDR
CHANNEL_NAME
CHANNEL_JOIN_COUNTER
CHANNEL_JOIN_MAX_RETRY
COMMIT
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
		configtxlator compute_update --channel_id ${CHANNEL_NAME} --original_config.pb --updated modified_config.pb >config_update.pb
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

join_channel_with_retry ()
{
	peer channel join -b ${CHANNEL_NAME}.block
	if [ $? -ne 0 -a ${CHANNEL_JOIN_COUNTER} -lt ${CHANNEL_JOIN_MAX_RETRY} ]; then
		COUNTER=` expr ${CHANNEL_JOIN_COUNTER} + 1`
		warn_log "${peer}.${org} join to ${CHANNEL_NAME} failed, retry after ${SLEEP_DELAY} seconds"
		sleep ${SLEEP_DELAY}
		join_channel_with_retry
	else
		COUNTER=1
	fi
	info_log "${peer}.${org} join ${CHANNEL_NAME} successful"
	sleep ${SLEEP_DELAY}
}
info_log "Fetching channel config block from orderer..."
(
	org=ext;peer=peer0;set_peer_globals
	peer channel fetch 0 ${CHANNEL_NAME}.block -o ${ORDERER_ADDR} -c ${CHANNEL_NAME} --tls --cafile ${ORDERER_CA}
)
info_log "Having ext peers join the channel..."
(
    org=ext;peer=peer0;set_peer_globals
    join_channel_with_retry
)