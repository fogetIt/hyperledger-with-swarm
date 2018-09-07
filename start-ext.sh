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
            docker-machine ssh ext 'docker swarm leave -f'
        fi
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
            docker-machine ssh ext 'if [ -d add ]; then rm -rf add; fi'
            docker-machine scp -r -q ${USER}@localhost:add docker@ext:add
            docker-machine ssh ext sh -s < script.sh add '1'

            docker-machine ssh manager 'if [ -d update ]; then rm -rf update; fi'
            docker-machine scp -r -q ${USER}@localhost:update docker@manager:update

            docker-machine scp -r -q docker@ext:add/channel-artifacts/ext.json ${HOME}/tmp/
            docker-machine scp -r -q ${USER}@localhost:${HOME}/tmp/ext.json docker@manager:update/channel-artifacts/

            docker-machine ssh manager sh -s < script.sh update '1'

            docker-machine scp -r -q docker@manager:fabric/crypto-config/ordererOrganizations ${HOME}/tmp/
            docker-machine scp -r -q ${USER}@localhost:${HOME}/tmp/ordererOrganizations docker@ext:add/crypto-config/
            docker-machine ssh ext sh -s < script.sh add '2' ${2:-'true'}
            if [[ ${2} == 'true' ]]; then
                docker-machine ssh manager sh -s < script.sh update '2'
                docker-machine ssh ext sh -s < script.sh add '3'
                docker-machine ssh manager sh -s < script.sh update '3'
                docker-machine ssh ext sh -s < script.sh add '4'
                docker-machine ssh manager sh -s < script.sh update '4'
            fi
        popd
    ;;
esac