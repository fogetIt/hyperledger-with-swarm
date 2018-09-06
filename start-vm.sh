#!/bin/bash
set -e
DIR=$(pwd)
vm_init ()
{
    machine=${1}
    if [[ -z $(docker-machine ls --filter NAME=${machine} -q) ]]; then
        memory=2048;[ -z ${2} ] || memory=5120
        # make sure ~/.docker/machine/cache/boot2docker.iso
        docker-machine create \
            --driver virtualbox \
            --virtualbox-memory ${memory} \
            --engine-registry-mirror "https://bsy887ib.mirror.aliyuncs.com" \
            --swarm ${2} ${machine}
    elif [[ $(docker-machine ls --filter NAME=${machine} --format "{{.State}}") == 'Stopped' ]]; then
        docker-machine start ${machine}
        docker-machine regenerate-certs ${machine} --force
        # remove swarm node
        docker-machine ssh ${machine} 'docker swarm leave -f'
    fi
    pushd requirements
        docker-machine ssh ${machine} sh -s < script.sh init
    popd
}
case ${1} in
    init)
        if ! docker-machine --version; then
            base=https://github.com/docker/machine/releases/download/v0.14.0
            curl -L $base/docker-machine-$(uname -s)-$(uname -m) >/tmp/docker-machine
            sudo install /tmp/docker-machine /usr/local/bin/docker-machine
        fi
        vm_init manager --swarm-master
        vm_init worker1
        vm_init worker2
        docker-machine ssh worker1 'docker pull hyperledger/fabric-ca:`uname -m`-1.1.0'
        echo "!!!Recreate the only global swarm token!!!"
        # manager_host=${${$(docker-machine url manager)#*//}%:*}
        manager_host=$(docker-machine url manager | cut -d / -f 3 | cut -d : -f 1)
        docker-machine ssh manager "docker swarm init --advertise-addr ${manager_host}"
        docker-machine ssh worker1
        docker-machine ssh worker2
        /bin/bash start-ext.sh init
        docker-machine ssh ext
    ;;
    down)
        if [[ ! -z $(docker-machine ssh manager 'docker service ls -q') ]]; then
            docker-machine ssh manager 'docker service rm $(docker service ls -q)'
        fi
        pushd requirements
            docker-machine ssh manager sh -s < script.sh down
            docker-machine ssh worker1 sh -s < script.sh down
            docker-machine ssh worker2 sh -s < script.sh down
        popd
        /bin/bash start-ext.sh down
    ;;
    up)
        python templates/build.py
        docker-machine ssh manager 'if [ -d fabric ]; then rm -rf fabric; fi'
        docker-machine scp -r -q ${USER}@localhost:fabric docker@manager:fabric
        pushd requirements
            docker-machine ssh manager sh -s < script.sh up ${2:-'true'}
        popd
    ;;
    composer)
        docker-machine ssh manager 'if [ -d composer ]; then rm -rf composer; fi'
        docker-machine scp -r -q ${USER}@localhost:composer docker@manager:composer
        pushd requirements
            docker-machine ssh manager sh -s < script.sh composer
        popd
    ;;
    explorer)
        docker-machine ssh manager 'if [ -d explorer ]; then rm -rf explorer; fi'
        docker-machine scp -r -q ${USER}@localhost:explorer docker@manager:explorer
        pushd requirements
            docker-machine ssh manager sh -s < script.sh explorer
        popd
    ;;
esac

: <<'COMMIT'
docker service ls --format "table {{.Name}}\t{{.Replicas}}"
docker service ps ov_composer_cli --format "{{.Error}}" --no-trunc
COMMIT