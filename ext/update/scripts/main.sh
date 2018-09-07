#!/bin/bash
: <<'COMMIT'
ORDERER_CA
ORDERER_ADDR
FABRIC_CFG_PATH
CHANNEL_NAME
STEP_NUMBER
COMMIT
apt -y update
apt -y install jq
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
    update_channel_configure
elif [ ${STEP_NUMBER} == 2 ]; then
    info_log "Install chaincode 2.0 on orgs peer0..."
	(
		org=zjhl;peer=peer0;set_peer_globals;install_chaincode 2.0
	)
	info_log "Upgrading chaincode on peer0.zjhl"
	(
	    org=zjhl;peer=peer0;set_peer_globals;upgrade_chaincode
	)
elif [ ${STEP_NUMBER} == 3 ]; then
	info_log "Sending invoke transaction on orgs peer0..."
	(
	    chaincode_invoke peer0 zjhl
	)
elif [ ${STEP_NUMBER} == 4 ]; then
    info_log "Querying chaincode on orgs peer0..."
	(
		org=zjhl;peer=peer0;set_peer_globals;chaincode_query 80
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