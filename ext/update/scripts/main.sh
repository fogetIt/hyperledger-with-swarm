#!/bin/bash
source utils.sh
apt -y update
apt -y install jq
set -e
set -x
pushd ${FABRIC_CFG_PATH}/scripts
    echo
    echo " ____    _____      _      ____    _____ "
    echo "/ ___|  |_   _|    / \    |  _ \  |_   _|"
    echo "\___ \    | |     / _ \   | |_) |   | |  "
    echo " ___) |   | |    / ___ \  |  _ <    | |  "
    echo "|____/    |_|   /_/   \_\ |_| \_\   |_|  "
    echo
    echo "Extend your first network (EYFN) test"
    echo
    export SLEEP_DELAY=3
	/bin/bash channel.sh
	if [ ${CC_TEST} == 'true' ]; then
		/bin/bash chaincode.sh
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
popd