#!/bin/bash
set -e
source utils.sh
pushd ${FABRIC_CFG_PATH}/scripts
	/bin/bash generate.sh > /tmp/generate.log
	echo
	echo " ____    _____      _      ____    _____ "
	echo "/ ___|  |_   _|    / \    |  _ \  |_   _|"
	echo "\___ \    | |     / _ \   | |_) |   | |  "
	echo " ___) |   | |    / ___ \  |  _ <    | |  "
	echo "|____/    |_|   /_/   \_\ |_| \_\   |_|  "
	echo
	echo "Build your first network (BYFN) end-to-end test"
	echo
	export SLEEP_DELAY=3
	set -x
	/bin/sh wait-for zookeeper0.orderers.com:2181 -t 600 -- sleep 1
	/bin/sh wait-for zookeeper1.orderers.com:2181 -t 10 -- sleep 1
	/bin/sh wait-for zookeeper2.orderers.com:2181 -t 10 -- sleep 1
	/bin/sh wait-for kafka0.orderers.com:9092 -t 10 -- sleep 1
	/bin/sh wait-for kafka1.orderers.com:9092 -t 10 -- sleep 1
	/bin/sh wait-for kafka2.orderers.com:9092 -t 10 -- sleep 1
	/bin/sh wait-for kafka3.orderers.com:9092 -t 10 -- sleep 1
	/bin/sh wait-for orderer0.orderers.com:7050 -t 10 -- sleep 1
	/bin/sh wait-for orderer1.orderers.com:7050 -t 10 -- sleep 1
	/bin/sh wait-for orderer2.orderers.com:7050 -t 10 -- sleep 1
	/bin/sh wait-for couchdb0.zjhl.com:5984 -t 10 -- sleep 1
	/bin/sh wait-for couchdb1.zjhl.com:5984 -t 10 -- sleep 1
	/bin/sh wait-for couchdb2.zjhl.com:5984 -t 10 -- sleep 1
	/bin/sh wait-for peer0.zjhl.com:7051 -t 10 -- sleep 1
	/bin/sh wait-for peer0.zjhl.com:7053 -t 10 -- sleep 1
	/bin/sh wait-for peer1.zjhl.com:7051 -t 10 -- sleep 1
	/bin/sh wait-for peer1.zjhl.com:7053 -t 10 -- sleep 1
	/bin/sh wait-for peer2.zjhl.com:7051 -t 10 -- sleep 1
	/bin/sh wait-for peer2.zjhl.com:7053 -t 10 -- sleep 1
	set +x
	/bin/bash channel.sh
	if [ ${CC_TEST} == 'true' ]; then
		/bin/bash chaincode.sh
	fi
	echo
	echo "========= All GOOD, BYFN execution completed =========== "
	echo
	echo " _____   _   _   ____   "
	echo "| ____| | \ | | |  _ \  "
	echo "|  _|   |  \| | | | | | "
	echo "| |___  | |\  | | |_| | "
	echo "|_____| |_| \_| |____/  "
	echo
popd
exit 0
