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
clear_containers ()
{
    containers=$(docker ps -aq)
    if [ -z "${containers}" -o "${containers}" == " " ]; then
        info_log "No containers available for deletion"
    else
        docker rm -f ${containers}
    fi
}
remove_unwanted_images ()
{
    images=$(docker images | grep "dev\|test-vp\|peer[0-9]-" | awk '{print $3}')
    if [ ! -z "${images}" -a "${images}" != " " ]; then
        docker rmi -f ${images}
    fi
    images=$(docker images --format "table{{.Repository}}\t{{.ID}}" | grep none | awk '{print $2}')
    if [ -z "${images}" -o "${images}" == " " ]; then
        info_log "No images available for deletion"
    else
        docker rmi -f ${images}
    fi
}
clear_volumes ()
{
    info_log "Remove local volumes"
    echo 'y' | docker volume prune
    sshfs_volumes=$(docker volume ls -q)
    info_log "Remove vieux/sshfs volumes"
    if [ -z "${sshfs_volumes}" -o "${sshfs_volumes}" == " " ]; then
        info_log "No vieux/sshfs volumes available for deletion"
    else
        docker volume rm ${sshfs_volumes}
    fi
}
case ${1} in
    init)
        # on ext node
        # tce-load -wi python
        # curl https://bootstrap.pypa.io/get-pip.py | sudo python -
        # sudo pip install docker-compose
        if ! docker-compose --version; then
            sudo curl \
                -L https://get.daocloud.io/docker/compose/releases/download/1.22.0/docker-compose-`uname -s`-`uname -m` \
                -o /usr/local/bin/docker-compose -k
            sudo chmod +x /usr/local/bin/docker-compose
        fi
        version=${FABRIC_VERSION} && get_fabric_images ca peer ccenv tools orderer
        version=${DEPEND_VERSION} && get_fabric_images baseos baseimage couchdb
    ;;
    down)
        # on ext node
        clear_containers
        remove_unwanted_images
        clear_volumes
    ;;
    add)
        # on ext node
        (cd ~/add
            sed -i s/{{DOMAIN}}/ext/g configtx.yaml
            sed -i s/{{DOMAIN}}/ext/g crypto-config.yaml
            docker-compose -f fabric-cli.yaml up
            docker-compose -f fabric-cli.yaml rm -f
            sudo chmod -R 777 crypto-config channel-artifacts
            sudo chown -R ${USER} crypto-config channel-artifacts
            sudo chgrp -R staff crypto-config channel-artifacts
            sed -i s/{{DOMAIN}}/ext/g docker-compose.yml
            export CA_KEYFILE=$(ls -1 crypto-config/peerOrganizations/ext.com/ca/*_sk | cut -d / -f 5)
            docker-compose up -d
        )
        docker network connect ${COMPOSE_PROJECT_NAME}_${NETWORK_NAME} ca.ext.com
        docker network connect ${COMPOSE_PROJECT_NAME}_${NETWORK_NAME} peer0.ext.com
        docker network connect ${COMPOSE_PROJECT_NAME}_${NETWORK_NAME} couchdb0.ext.com
    ;;
    update)
        # on manager node
        (cd ~/update
            docker stack deploy -c fabric-cli.yaml ov
        )
        while test $(docker service ls --filter NAME=ov_cli_update --format "{{.Replicas}}") != '1/1'; do
            sleep 5
        done
        docker service logs ov_cli_update --raw
    ;;
    ext)
        # on ext node
        (cd ~/add
            export CC_TEST=${2:-'true'}
            docker-compose -f ext.yaml up
            docker-compose -f ext.yaml rm -f
        )
    ;;
esac