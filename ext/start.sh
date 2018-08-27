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
    ;;
    up)
    ;;
esac