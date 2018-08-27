#!/bin/bash
source utils.sh
: <<'COMMIT'
ORDERER_CA
ORDERER_ADDR
CHANNEL_NAME
SLEEP_DELAY
CC_LANGUAGE
CC_SRC_PATH
CC_QUERY_TIMEOUT
COMMIT

export CC_SRC_PATH='github.com/chaincode/chaincode_example02/go/'
if [ "${CC_LANGUAGE}" = 'node' ]; then
	export CC_SRC_PATH='/opt/gopath/src/github.com/chaincode/chaincode_example02/node/'
fi
export CC_LANGUAGE=`echo "${CC_LANGUAGE}" | tr [:upper:] [:lower:]`

install_chaincode ()
{
	VERSION=${1:-1.0}
	peer chaincode install -n mycc -v ${VERSION} -l ${CC_LANGUAGE} -p ${CC_SRC_PATH}
	info_log "Chaincode is installed on ${peer}.${org}"
}
instantiate_chaincode ()
{
	VERSION=${1:-1.0}
	peer chaincode instantiate -o ${ORDERER_ADDR} --tls --cafile ${ORDERER_CA} -C ${CHANNEL_NAME} -n mycc -v ${VERSION} -l ${CC_LANGUAGE} -c '{"Args":["init","a","100","b","200"]}' -P "OR	('zjhlMSP.member')"
	info_log "Chaincode Instantiation on ${peer}.${org} on ${CHANNEL_NAME} is successful"
}
chaincode_query ()
{
	set +e
    EXPECTED_RESULT=${1}
	: ${EXPECTED_RESULT:=100}
    info_log "Querying on ${peer}.${org} on channel '${CHANNEL_NAME}'..."
    local rc=1
    local starttime=$(date +%s)
    # continue to poll
    # we either get a successful response, or reach CC_QUERY_TIMEOUT
    while test "$(($(date +%s)-starttime))" -lt "${CC_QUERY_TIMEOUT}" -a $rc -ne 0;do
		sleep ${SLEEP_DELAY}
		info_log "Attempting to Query ${peer}.${org} ...$(($(date +%s)-starttime)) secs"
		peer chaincode query -C ${CHANNEL_NAME} -n mycc -c '{"Args":["query","a"]}' >& /tmp/log.txt
		test $? -eq 0 && VALUE=$(cat /tmp/log.txt | awk '/Query Result/ {print $NF}')
		test "$VALUE" = "$EXPECTED_RESULT" && let rc=0
    done
	cat /tmp/log.txt
	if test $rc -eq 0; then
		info_log "Query on ${peer}.${org} on channel '${CHANNEL_NAME}' is successful"
	else
		error_log "Query on ${peer}.${org} on channel '${CHANNEL_NAME}' is failed"
		exit 1
	fi
	set -e
}
chaincode_invoke ()
{
	# while 'peer chaincode' command can get the orderer endpoint from the peer (if join was successful),
	# lets supply it directly as we know it using the "-o" option
	peer chaincode invoke -o ${ORDERER_ADDR} --tls --cafile ${ORDERER_CA} -C ${CHANNEL_NAME} -n mycc -c '{"Args":["invoke","a","b","10"]}'
	info_log "Invoke transaction on ${peer}.${org} on channel '${CHANNEL_NAME}' is successful"
}

set_orderer_global
info_log "Install chaincode for peers..."
(
	org=zjhl;peer=peer0;set_peer_globals;install_chaincode
	org=zjhl;peer=peer1;set_peer_globals;install_chaincode
	org=zjhl;peer=peer2;set_peer_globals;install_chaincode
)
info_log "Instantiating chaincode on peers..."
(
	org=zjhl;peer=peer0;set_peer_globals;instantiate_chaincode
)
info_log "Querying chaincode on peers..."
(
	org=zjhl;peer=peer0;set_peer_globals;chaincode_query 100
	org=zjhl;peer=peer1;set_peer_globals;chaincode_query 100
	org=zjhl;peer=peer2;set_peer_globals;chaincode_query 100
)
info_log "Sending invoke transaction on peers..."
(
	org=zjhl;peer=peer0;set_peer_globals;chaincode_invoke
)
info_log "Querying chaincode on peers..."
(
	org=zjhl;peer=peer0;set_peer_globals;chaincode_query 90
	org=zjhl;peer=peer1;set_peer_globals;chaincode_query 90
	org=zjhl;peer=peer2;set_peer_globals;chaincode_query 90
)