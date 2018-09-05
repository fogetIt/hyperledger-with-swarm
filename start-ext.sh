#!/bin/bash
set -e
case ${1} in
    init)
        if [[ -z $(docker-machine ls --filter NAME=ext -q) ]]; then
            docker-machine create \
                --driver virtualbox \
                --virtualbox-memory 2048 \
                --engine-registry-mirror "https://bsy887ib.mirror.aliyuncs.com" \
                --swarm ext
        elif [[ $(docker-machine ls --filter NAME=ext --format "{{.State}}") == 'Stopped' ]]; then
            docker-machine start ext
            docker-machine regenerate-certs ext --force
        fi
        docker-machine ssh ext 'if [ -d ext ]; then rm -rf ext; fi'
        docker-machine scp -r -q ${USER}@localhost:ext docker@ext:ext
        pushd ext
            docker-machine ssh ext sh -s < script.sh init
        popd
    ;;
    down)
        pushd ext
            docker-machine ssh ext sh -s < script.sh down
        popd
    ;;
    up)
        pushd ext
            docker-machine ssh ext sh -s < script.sh add

            docker-machine scp -r -q docker@manager:fabric/crypto-config/ordererOrganizations ${HOME}/tmp/
            docker-machine scp -r -q ${USER}@localhost:${HOME}/tmp/ordererOrganizations docker@ext:ext/crypto-config/

            docker-machine scp -r -q docker@manager:fabric/chaincode ${HOME}/tmp/
            docker-machine scp -r -q ${USER}@localhost:${HOME}/tmp/chaincode docker@ext:ext/update/

            docker-machine ssh ext sh -s < script.sh update ${2:-'true'}
        popd
    ;;
esac