# coding: utf-8
import os
import re
import platform

current_path = os.path.abspath(os.path.dirname(__file__))
# -----------------
# define constants
# -----------------
ZJHL_DOMAIN = "zjhl"
ORDERERS_DOMAIN = "orderers"
NETWORK_NAME = "hyperledger"
ARCH = platform.machine()
ZOO_SERVERS = "server.1=zookeeper0.{0}.com:2888:3888 server.2=zookeeper1.{0}.com:2888:3888 server.3=zookeeper2.{0}.com:2888:3888".format(ORDERERS_DOMAIN)
KAFKA_ZOOKEEPER_CONNECT = "zookeeper0.{0}.com:2181,zookeeper1.{0}.com:2181,zookeeper2.{0}.com:2181".format(ORDERERS_DOMAIN)

KAFKA_WAIT_FOR = "wait-for zookeeper0.{0}.com:2181 -t 5 -- wait-for zookeeper1.{0}.com:2181 -t 5 -- wait-for zookeeper2.{0}.com:2181 -t 5".format(ORDERERS_DOMAIN)

ORDERER_WAIT_FOR = "wait-for kafka0.{0}.com:9092 -t 5 -- wait-for kafka0.{0}.com:9093 -t 5 -- wait-for kafka1.{0}.com:9092 -t 5 -- wait-for kafka1.{0}.com:9093 -t 5 -- wait-for kafka2.{0}.com:9092 -t 5 -- wait-for kafka2.{0}.com:9093 -t 5 -- wait-for kafka3.{0}.com:9092 -t 5 -- wait-for kafka3.{0}.com:9093 -t 5".format(ORDERERS_DOMAIN)


def parser(*file_paths):
    with open(os.path.join(current_path, *file_paths), 'r') as f:
        string = re.sub('.*#.*\n', '', f.read())
        pattern = re.compile(r'{{[^}]+}}')
        matched = pattern.findall(string)
        for s in matched:
            string = string.replace(s, str(eval(s.strip('{}'))))
    return string + "\n\n"
# ----------------------------------------
# build crypto-config.yaml & configtx.yaml
# ----------------------------------------
configtx = os.path.join(os.path.dirname(current_path), "fabric", "configtx.yaml")
crypto_config = os.path.join(os.path.dirname(current_path), "fabric", "crypto-config.yaml")
with open(crypto_config, 'w') as crypto_config, open(configtx, 'w') as configtx:
    configtx.write(parser("fabric", "configtx.yaml"))
    crypto_config.write(parser("fabric", "crypto-config.yaml"))
# ------------------------------------------
# build docker-compose.yml & fabric-cli.yaml
# ------------------------------------------
# sys.argv[1] == "dev"


def fabric_docker_compose_parser(index, machine_name, template_file):
    global INDEX, MACHINE_NAME
    INDEX = index
    MACHINE_NAME = machine_name
    return parser('fabric', "docker-compose", template_file)
docker_compose = parser("fabric", "docker-compose", "header.yaml") + \
fabric_docker_compose_parser(0, "manager", "couchdb.yaml") + \
fabric_docker_compose_parser(1, "worker1", "couchdb.yaml") + \
fabric_docker_compose_parser(2, "worker2", "couchdb.yaml") + \
fabric_docker_compose_parser(0, "manager", "peer.yaml") + \
fabric_docker_compose_parser(1, "worker1", "peer.yaml") + \
fabric_docker_compose_parser(2, "worker2", "peer.yaml") + \
fabric_docker_compose_parser(0, "manager", "zookeeper.yaml") + \
fabric_docker_compose_parser(1, "worker1", "zookeeper.yaml") + \
fabric_docker_compose_parser(2, "worker2", "zookeeper.yaml") + \
fabric_docker_compose_parser(0, "manager", "kafka.yaml") + \
fabric_docker_compose_parser(1, "worker1", "kafka.yaml") + \
fabric_docker_compose_parser(2, "worker2", "kafka.yaml") + \
fabric_docker_compose_parser(3, "manager", "kafka.yaml") + \
fabric_docker_compose_parser(0, "manager", "orderer.yaml") + \
fabric_docker_compose_parser(1, "worker1", "orderer.yaml") + \
fabric_docker_compose_parser(2, "worker2", "orderer.yaml") + \
fabric_docker_compose_parser(0, "manager", "ca.yaml")
with open(os.path.join(os.path.dirname(current_path), "fabric", "docker-compose.yml"), "w") as f:
    f.write(docker_compose)


MACHINE_NAME = "manager"
with open(os.path.join(os.path.dirname(current_path), "fabric", "fabric-cli.yaml"), 'w') as f:
    f.write(parser("fabric", "fabric-cli.yaml"))