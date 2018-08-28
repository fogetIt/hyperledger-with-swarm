#!/bin/bash
set -e
export NODE_HOSTNAME='ext'
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
        docker-machine scp -r -q ${USER}@localhost:ext docker@${NODE_HOSTNAME}:ext
        pushd ext
            docker-machine ssh ${NODE_HOSTNAME} sh -s < script.sh init
        popd
    ;;
    down)
        pushd ext
            docker-machine ssh ${NODE_HOSTNAME} sh -s < script.sh down
        popd
    ;;
    up)
        pushd ext
            docker-machine ssh ${NODE_HOSTNAME} sh -s < script.sh up
        popd
    ;;
esac