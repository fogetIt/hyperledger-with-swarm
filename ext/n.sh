#!/bin/bash
set -e
. utils.sh

inner_dir=/home/docker/extend
outer_dir="${HOME}/multi/manager/extend"
re_mount manager
cp -R extend/* ${outer_dir}
if [ ! -z $(docker-machine ssh manager "docker service ls -q --filter NAME=ov_extender") ]; then
    docker-machine ssh manager "docker service rm ov_extender"
fi
case ${1} in
    init)
    if [ -z $(docker-machine ssh manager "docker images hyperledger/extender:latest -q") ]; then
        docker-machine ssh manager \
            "cd extend;docker build --build-arg FABRIC_VERSION=${FABRIC_VERSION} --tag hyperledger/extender:latest ."
    fi
docker-machine ssh manager <<eeooff
tce-load -wi python
curl https://bootstrap.pypa.io/get-pip.py | sudo python -
sudo pip install docker-compose
eeooff
    ;;
    up)
docker-machine ssh manager <<eeooff
. ~/extend/utils.sh
cd extend
docker stack deploy -c extender.yaml ov
eeooff
    ;;
esac
