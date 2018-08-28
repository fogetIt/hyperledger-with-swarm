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

case ${1} in
    init)
        tce-load -wi python
        curl https://bootstrap.pypa.io/get-pip.py | sudo python -
        sudo pip install docker-compose
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