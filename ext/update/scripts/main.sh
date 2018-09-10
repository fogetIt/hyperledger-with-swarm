#!/bin/bash
: <<'COMMIT'
ORDERER_CA
ORDERER_ADDR
FABRIC_CFG_PATH
CHANNEL_NAME
STEP_NUMBER
COMMIT
set +e
apt -y update
apt -y install jq
set -e
source utils.sh
source chaincode.sh
set -e
echo
echo " _   _   ____    ____       _      _____   _____  "
echo "| | | | |  _ \  |  _ \     / \    |_   _| | ____| "
echo "| | | | | |_) | | | | |   / _ \     | |   |  _|   "
echo "| |_| | | |__/  | |_| |  / ___ \    | |   | |___  "
echo " \___/  |_|     |____/  /_/   \_\   |_|   |_____| "
echo
echo "Extend your first network (EYFN) test"
echo
set_orderer_globals
export SLEEP_DELAY=3
case ${STEP_NUMBER} in
	'1')
    	update_channel_configure
	;;
	'2')
		info_log "Install chaincode 2.0 on orgs peer0..."
		(
			org=zjhl;peer=peer0;set_peer_globals;install_chaincode 2.0
		)
		info_log "Upgrading chaincode on peer0.zjhl"
		(
			org=zjhl;peer=peer0;set_peer_globals;upgrade_chaincode
		)
	;;
	'3')
		info_log "Sending invoke transaction on orgs peer0..."
		(
			chaincode_invoke peer0 zjhl
		)
	;;
	'4')
		info_log "Querying chaincode on orgs peer0..."
		(
			org=zjhl;peer=peer0;set_peer_globals;chaincode_query 80
		)
	;;
esac
echo
echo "========= All GOOD, EYFN test execution completed =========== "
echo
echo " _____   _   _   ____   "
echo "| ____| | \ | | |  _ \  "
echo "|  _|   |  \| | | | | | "
echo "| |___  | |\  | | |_| | "
echo "|_____| |_| \_| |____/  "
echo