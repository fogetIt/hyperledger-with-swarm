#!/bin/bash
set -e
source utils.sh
: <<'COMMIT'
ORDERER_CA
ORDERER_ADDR
CHANNEL_NAME
CHANNEL_JOIN_COUNTER
CHANNEL_JOIN_MAX_RETRY
COMMIT
set_orderer_globals
export SLEEP_DELAY=3

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
pushd "${FABRIC_CFG_PATH}/channel-artifacts"
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
popd
if [ ${CC_TEST} == 'true' ]; then
	/bin/bash chaincode.sh
fi