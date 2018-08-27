#!/bin/bash
set -eu -o pipefail
sudo locale-gen zh_CN.UTF-8
sudo apt install -y git unzip

source /etc/lsb-release
CODENAME=${DISTRIB_CODENAME}
if ! docker -v; then
    # Add Docker repository key to APT keychain
    # curl -O https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    curl -O https://raw.githubusercontent.com/fogetIt/hyperledger-with-swarm/tmp/requirements/gpg | sudo apt-key add -
    echo "deb [arch=amd64] https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/ubuntu ${CODENAME} stable" | sudo tee /etc/apt/sources.list.d/docker.list
    # 安装证书服务，确保 apt 能使用 https
    sudo apt -y install ca-certificates apt-transport-https
    set +e
    sudo apt update
    set -e
    sudo apt-cache policy docker-ce
    sudo apt -y install docker-ce
fi
[[ -d /etc/docker ]] || sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json <<-'EOF'
{
  "registry-mirrors": ["https://bsy887ib.mirror.aliyuncs.com"]
}
EOF
sudo usermod -aG docker $(whoami)
sudo systemctl daemon-reload
sudo systemctl restart docker

sudo apt install -y sshfs

set +e
COUNT="$(python -V 2>&1 | grep -c 2.)"
if [ ${COUNT} -ne 1 ]
then
   sudo apt install -y python-minimal
fi
set -e
sudo apt install -y python-pip


echo ''
echo 'Installation completed, versions installed are:'
echo ''
echo -n 'Docker:         '
docker --version
echo -n 'Python:         '
python -V
echo ''
echo "Please logout then login before continuing."
