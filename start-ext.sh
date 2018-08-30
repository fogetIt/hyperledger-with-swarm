#!/bin/bash
set -e
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
        popd
        docker-machine scp -r -q \
            docker@manager:fabric/crypto-config/ordererOrganizations \
            docker@ext:ext/crypto-config/
    ;;
esac