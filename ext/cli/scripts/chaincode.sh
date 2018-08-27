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
export CC_SRC_PATH="github.com/chaincode/chaincode_example02/go/"
if [ "${CC_LANGUAGE}" = "node" ]; then
	export CC_SRC_PATH="/opt/gopath/src/github.com/chaincode/chaincode_example02/node/"
fi
export CC_LANGUAGE=`echo "${CC_LANGUAGE}" | tr [:upper:] [:lower:]`

install_chaincode ()
{
	VERSION=${1:-1.0}
	peer chaincode install -n mycc -v ${VERSION} -l ${CC_LANGUAGE} -p ${CC_SRC_PATH}
	info_log "Chaincode is installed on ${peer}.${org}"
}
upgrade_chaincode ()
{
    peer chaincode upgrade \
        -o ${ORDERER_ADDR} --tls --cafile ${ORDERER_CA} -C ${CHANNEL_NAME} -n mycc -v 2.0 \
        -c '{"Args":["init","a","90","b","210"]}' -P "AND ('zjhlMSP.peer','extMSP.peer')"
    info_log "Chaincode is upgraded on ${peer}.${org} successfully"
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
parse_peer_connection_parameters()
{
    # check for uneven number of peer and org parameters
    if [ $(($# % 2)) -ne 0 ]; then
        exit 1
    fi
    PEER_CONN_PARMS=""
    PEERS=""
    while [ "$#" -gt 0 ]; do
        peer=$1;org=$2
        PEERS="${PEERS} ${peer}.${org}"
        TLSINFO=$(eval echo "--tlsRootCertFiles \$$(echo ${peer} | tr [:lower:] [:upper:])_$(echo ${org} | tr [:lower:] [:upper:])_CA")
        PEER_CONN_PARMS="${PEER_CONN_PARMS} --peerAddresses ${peer}.${org}.com:7051 ${TLSINFO}"
        # shift by two to get the next pair of peer/org parameters
        shift;shift
    done
    # remove leading space for output
    PEERS="$(echo -e "${PEERS}" | sed -e 's/^[[:space:]]*//')"
}
chaincode_invoke ()
{
    parse_peer_connection_parameters $@
	# while 'peer chaincode' command can get the orderer endpoint from the peer (if join was successful),
	# lets supply it directly as we know it using the "-o" option
    peer chaincode invoke -o ${ORDERER_ADDR} --tls --cafile ${ORDERER_CA} -C ${CHANNEL_NAME} -n mycc ${PEER_CONN_PARMS} -c '{"Args":["invoke","a","b","10"]}'
	info_log "Invoke transaction on ${peer}.${org} on channel '${CHANNEL_NAME}' is successful"
}
info_log "Install chaincode 2.0 on orgs peer0..."
(
    org=ext;peer=peer0;set_peer_globals;install_chaincode 2.0
	org=zjhl;peer=peer0;set_peer_globals;install_chaincode 2.0
)
info_log "Upgrading chaincode on peer0.zjhl"
(
    org=zjhl;peer=peer0;set_peer_globals;upgrade_chaincode
)
info_log "Querying chaincode on peer0.ext..."
(
	org=ext;peer=peer0;set_peer_globals;chaincode_query 90
)
info_log "Sending invoke transaction on orgs peer0..."
(
    chaincode_invoke peer0 zjhl peer0 ext
)
info_log "Querying chaincode on orgs peer0..."
(
	org=zjhl;peer=peer0;set_peer_globals;chaincode_query 80
	org=ext;peer=peer0;set_peer_globals;chaincode_query 80
)