#!/bin/sh
set -e
export ARCH=`uname -m`
export COMPOSE_PROJECT_NAME='ov'
export NETWORK_NAME='hyperledger'
export LOG_LEVEL='info'

export COMPOSER_VERSION='0.19.12'
export NODE_HOSTNAME='ext'

export CHANNEL_NAME='mychannel'
export FABRIC_VERSION='1.1.0'
export DEPEND_VERSION='0.4.6'
export FABRIC_IMAGE_TAG="${ARCH}-${FABRIC_VERSION}"
export DEPEND_IMAGE_TAG="${ARCH}-${DEPEND_VERSION}"
info_log ()
{
    echo -e "\033[32m=====> INFO: ${1}\033[0m"
}
warn_log ()
{
    echo -e "\033[33m=====> WARN: ${1}\033[0m"
}
error_log ()
{
    echo -e "\033[31m=====> ERROR: ${1}\033[0m"
}
get_fabric_images ()
{
    for name in ${@}; do
        info_log "Pulling hyperledger/fabric-${name}:${ARCH}-${version}"
        docker pull "hyperledger/fabric-${name}:${ARCH}-${version}"
        # docker tag "hyperledger/fabric-${name}:${ARCH}-${version}" "hyperledger/fabric-${name}:latest"
    done
}
case ${1} in
    init)
        tce-load -wi python
        curl https://bootstrap.pypa.io/get-pip.py | sudo python -
        sudo pip install docker-compose
        version=${DEPEND_VERSION} && get_fabric_images couchdb
        version=${FABRIC_VERSION} && get_fabric_images ca peer ccenv tools orderer
    ;;
    down)
        (cd ~/ext/ext
            docker-compose rm -f
        )
    ;;
    up)
        (cd ~/ext/ext
            sed -i s/{{DOMAIN}}/ext/g configtx.yaml
            sed -i s/{{DOMAIN}}/ext/g crypto-config.yaml
            docker-compose up -d
        )
    ;;
esac