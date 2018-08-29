#!/bin/sh
set -e
export ARCH=`uname -m`
export COMPOSE_PROJECT_NAME='ov'
export NETWORK_NAME='hyperledger'
export LOG_LEVEL='info'

export COMPOSER_VERSION='0.19.12'
export NODE_HOSTNAME='manager'

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
set_fabric_globals ()
{
    cd ~/fabric
        while [ ! -d crypto-config/peerOrganizations/zjhl.com/ca ]; do
            sleep 5
        done
        export ZJHL_CA_KEYFILE=$(ls -1 crypto-config/peerOrganizations/zjhl.com/ca/*_sk | cut -d / -f 5)
        while [ ! -f channel-artifacts/genesis.block ]; do
            sleep 5
        done
        while [ ! -f channel-artifacts/channel.tx ]; do
            sleep 5
        done
        while [ ! -f channel-artifacts/zjhlMSPanchors.tx ]; do
            sleep 5
        done
        cat generate.log
        sudo chmod -R 777 crypto-config channel-artifacts
        sudo chown -R ${USER} crypto-config channel-artifacts
        sudo chgrp -R staff crypto-config channel-artifacts
        export MANAGER_HOST=$(docker node inspect --format "{{.Status}}" manager | cut -d ' ' -f 3 | cut -d '}' -f 1)
        export MANAGER_PASSWD='tcuser'
    cd -
}
set_composer ()
{
    (cd ~/fabric/crypto-config
        FABRIC_CONFIG=~/composer/fabric-config
        (cd ordererOrganizations/orderers.com/orderers/orderer0.orderers.com/tls
            awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' ca.crt > ${FABRIC_CONFIG}/ca-orderers.txt
        )
        (cd peerOrganizations/zjhl.com/peers/peer0.zjhl.com/tls
            awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' ca.crt > ${FABRIC_CONFIG}/ca-zjhl.txt
        )
        (cd peerOrganizations/zjhl.com/users/Admin@zjhl.com/msp
            /bin/cp -f signcerts/Admin@zjhl.com-cert.pem keystore/*_sk ${FABRIC_CONFIG}
        )
    )
    (cd ~/composer
        sed -i s/{{ZJHL_DOMAIN}}/zjhl/g zjhl.json
        sed -i s/{{ORDERERS_DOMAIN}}/orderers/g zjhl.json
        python replace.py
        [ -d 644ApiDoc ] || git clone https://github.com/mitusisi644/644ApiDoc.git
    )
}
wait_composer ()
{
    while test $(docker service ls --filter NAME=ov_ca_zjhl --format "{{.Replicas}}") != '1/1'; do
        sleep 5
    done
}

case ${1} in
    init)
        version=${FABRIC_VERSION} && get_fabric_images peer ccenv tools orderer
        version=${DEPEND_VERSION} && get_fabric_images kafka couchdb zookeeper
        if [[ -z $(docker plugin ls | grep sshfs) ]]; then
            docker plugin install --grant-all-permissions vieux/sshfs
        fi
        docker build \
            --tag hyperledger/fabric-ccenv:${FABRIC_IMAGE_TAG} \
            --build-arg FABRIC_IMAGE_TAG=${FABRIC_IMAGE_TAG} . \
            -f -<<-EOF
            ARG FABRIC_IMAGE_TAG
            FROM hyperledger/fabric-ccenv:${FABRIC_IMAGE_TAG}
            RUN npm config set registry https://registry.npm.taobao.org && \
                npm config set disturl https://npm.taobao.org/dist && \
                npm config set grpc_node_binary_host_mirror https://npm.taobao.org/mirrors/grpc
            CMD ["/bin/bash"]
			EOF
    ;;
    down)
        clear_containers
        remove_unwanted_images
        clear_volumes
    ;;
    up)
        # only on manager node
        export CC_TEST=${2:-'true'}
        (cd ~/fabric
            (cd scripts
                [[ -f wait-for ]] || curl -O https://raw.githubusercontent.com/eficode/wait-for/master/wait-for
            )
            docker stack deploy -c fabric-cli.yaml ov
            info_log "Deploying fabric!"
            set_fabric_globals
            docker stack deploy -c docker-compose.yml ov
            info_log "Waiting cli!"
        )
        docker service logs ov_cli --raw --follow
    ;;
    composer)
        # only on ${NODE_HOSTNAME} node
        docker pull hyperledger/composer-cli:${COMPOSER_VERSION}
        docker pull hyperledger/composer-playground:${COMPOSER_VERSION}
        docker pull hyperledger/composer-rest-server:${COMPOSER_VERSION}
        python --version || tce-load -wi python
        if [ ! -z $(docker service ls -q --filter NAME=ov_composer_cli) ]; then
            docker service rm ov_composer_cli
        fi
        if [ ! -z $(docker service ls -q --filter NAME=ov_composer_playground) ]; then
            docker service rm ov_composer_playground
        fi
        if [ ! -z $(docker service ls -q --filter NAME=ov_composer_rest_server) ]; then
            docker service rm ov_composer_rest_server
        fi
        set_composer
        (cd ~/composer
            sed -i s/{{ZJHL_DOMAIN}}/zjhl/g composer.yaml
            docker stack deploy -c composer.yaml ov
        )
        wait_composer
        docker service logs ov_composer_cli --follow
    ;;
    explorer)
        # only on ${NODE_HOSTNAME} node
        docker pull centos/postgresql-96-centos7:latest
        if [ ! -z $(docker service ls -q --filter NAME=ov_postgresql) ];then
            docker service rm ov_postgresql
        fi
        if [ ! -z $(docker service ls -q --filter NAME=ov_explorer) ];then
            docker service rm ov_explorer
        fi
        if [ -z $(docker images hyperledger/explorer:latest -q) ]; then
            (cd ~/explorer
                [[ -f wait-for ]] || curl -O https://raw.githubusercontent.com/eficode/wait-for/master/wait-for
                docker build --tag hyperledger/explorer:latest .
            )
        fi
        (cd ~/explorer
            sed -i s/{{ZJHL_DOMAIN}}/zjhl/g explorer.yaml
            sed -i s/{{ZJHL_DOMAIN}}/zjhl/g config.json
            sed -i s/{{ORDERERS_DOMAIN}}/orderers/g config.json
            docker run --rm \
                -v ~/explorer:/usr/tmp hyperledger/fabric-tools:${FABRIC_IMAGE_TAG} \
                cp /usr/local/bin/configtxgen /usr/tmp/configtxgen
            docker stack deploy -c explorer.yaml ov
        )
        docker service logs ov_explorer --follow
    ;;
esac