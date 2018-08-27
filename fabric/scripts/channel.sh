#!/bin/bash
source utils.sh
: <<'COMMIT'
ORDERER_ADDR
ORDERER_CA
SLEEP_DELAY
CHANNEL_NAME
CHANNEL_JOIN_COUNTER
CHANNEL_JOIN_MAX_RETRY
COMMIT
info_log "Channel name : "$CHANNEL_NAME
create_channel ()
{
	peer channel create -o ${ORDERER_ADDR} --tls --cafile ${ORDERER_CA} -c ${CHANNEL_NAME} -t ${CHANNEL_CREATE_TIMEOUT} -f channel.tx
	info_log "Channel ${CHANNEL_NAME} is created successfully"
}
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
update_anchor_peers ()
{
	peer channel update -o ${ORDERER_ADDR} --tls --cafile ${ORDERER_CA} -c ${CHANNEL_NAME} -f ${CORE_PEER_LOCALMSPID}anchors.tx
	info_log "Anchor peer for ${CORE_PEER_LOCALMSPID} on ${CHANNEL_NAME} is updated successfully"
	sleep ${SLEEP_DELAY}
}

set_orderer_global
pushd ${FABRIC_CFG_PATH}/channel-artifacts
	info_log "Creating channel..."
	(
		org=zjhl;peer=peer0;set_peer_globals;create_channel
	)
	info_log "Having all peers join the channel..."
	(
		org=zjhl;peer=peer0;set_peer_globals;join_channel_with_retry
		org=zjhl;peer=peer1;set_peer_globals;join_channel_with_retry
		org=zjhl;peer=peer2;set_peer_globals;join_channel_with_retry
	)
	info_log "Updating anchor peers for zjhl..."
	(
		org=zjhl;peer=peer0;set_peer_globals;update_anchor_peers
	)
popd
