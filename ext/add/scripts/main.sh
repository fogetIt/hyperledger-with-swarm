#!/bin/bash
: <<'COMMIT'
ORDERER_CA
ORDERER_ADDR
FABRIC_CFG_PATH
CHANNEL_NAME
CHANNEL_JOIN_COUNTER
CHANNEL_JOIN_MAX_RETRY
STEP_NUMBER
COMMIT
set -e
source utils.sh
source chaincode.sh
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
export SLEEP_DELAY=3
if [ ${STEP_NUMBER} == 1 ]; then
	cryptogen generate --config=./crypto-config.yaml
	configtxgen -printOrg extMSP > ./channel-artifacts/ext.json
elif [ ${STEP_NUMBER} == 2 ]; then
	pushd "${FABRIC_CFG_PATH}/channel-artifacts"
		info_log "Fetching channel config block from orderer..."
		(
			org=ext;peer=peer0;set_peer_globals
			peer channel fetch 0 ${CHANNEL_NAME}.block -o ${ORDERER_ADDR} -c ${CHANNEL_NAME} --tls --cafile ${ORDERER_CA}
		)
		info_log "Having ext peers join the channel..."
		(
			org=ext;peer=peer0;set_peer_globals;join_channel_with_retry
		)
	popd
	if [ ${CC_TEST} == 'true' ]; then
		info_log "Install chaincode 2.0 on orgs peer0..."
		(
			org=ext;peer=peer0;set_peer_globals;install_chaincode 2.0
		)
	fi
elif [ ${STEP_NUMBER} == 3 ]; then
	info_log "Querying chaincode on peer0.ext..."
	(
		org=ext;peer=peer0;set_peer_globals;chaincode_query 90
	)
	info_log "Sending invoke transaction on orgs peer0..."
	(
	    chaincode_invoke peer0 ext
	)
elif [ ${STEP_NUMBER} == 4 ]; then
	info_log "Querying chaincode on orgs peer0..."
	(
		org=ext;peer=peer0;set_peer_globals;chaincode_query 80
	)
fi
echo
echo "========= All GOOD, EYFN test execution completed =========== "
echo
echo " _____   _   _   ____   "
echo "| ____| | \ | | |  _ \  "
echo "|  _|   |  \| | | | | | "
echo "| |___  | |\  | | |_| | "
echo "|_____| |_| \_| |____/  "
echo