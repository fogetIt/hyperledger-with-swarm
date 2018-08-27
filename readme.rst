节点
----
- peers 组成 org ， orgs 组成 channel

:fabric-ca: 会员注册和证书颁发节点

    - 每个 org 需要一个 ca 节点
    - fabric 系统的参与方（ orderer,peer,client ）都必须经过授权，需要拥有受信任的证书
    - 在 1.0 版本中， CA 可以脱离 docker 和节点，作为一个独立的服务来运行

:fabric-orderer: 共识网络节点

    - 每个 channel 需要一个 orderer 集群
    - 多方一起参与交易排序，生成新的区块，发送给 peer 节点
    - orderer 拥有所有通道的 blockfile ，但是它没有世界状态，无法查询交易，只是为了方便 peer 节点拉取

:fabric-peer: 区块链节点

    - peer 节点收到区块后，会对区块中的每笔交易进行校验，检查交易依赖的输入输出是否符合当前区块链的状态，完成后
        - 将 leager 写入 blockfile
        - 修改 world state

交易过程
-------------
- ChainCode 的一次调⽤
    - 应⽤（客户端）向 1～多个 peer 节点发送对事务的背书请求
    - 背书（endorsement）节点（模拟）执⾏ chaincode ，将原始交易提案（proposal）和执行结果打包到一起，进行签名并发回给客户端
        - 交易提案中包含本次交易要调用的合约标识、合约方法和参数信息以及客户端签名等
        - 每个交易提案（proposal）要么是 chaincode instantiate ，要么是 chaincode invoke
        - 在模拟执行交易期间产生的数据修改不会写到账本上
    - 应⽤（客户端）收集所有背书节点的结果后，广播给 orderers
    - orderers 执⾏行共识过程，并生成 block ，通过消息通道批量的将 block 发布给 peer 节点
    - 各个 peer 节点验证交易，并提交到本地账本中


账本
----------
- 账本与 channel 是一对一的关系

:leager:

    :blockfile: 存储在 peer 上的文件系统，记录 transaction 历史集合（交易共识系统排序后产生的区块数据）

        - 每个文件有大小限制，存储一定数量的区块
        - 每个区块包含一条或多条交易

    :index: 存储在 peer 上的 LevelDB 数据库，记录区块索引
    :world state: K-V 形式的世界状态数据库，提供给 chaincode 存取使用，用于快速查询当前状态

        - 可以使用 peer 内置的 LevelDB ，也可以外挂 CouchDB


工具
--------

:composer: npm composer-cli 模块镜像

    - fabric 节点间通过 connection.json 互相寻址、通信
    - 添加管理员用户，并同步给节点
    - 部署业务网络
        - 基于 fabric-ccenv 镜像，为每个组织的 peer 启动一个 chaincode 容器(composer network start/peer chaincode instantiate)
        - chaincode 容器中包含了 java/node/go 的运行环境，用来保存和执行链码

:cli: fabric-tools 工具集镜像

    :configtxgen:

        - 生成创世区块 orderer genesis block
            - 用来给 Orderer 节点做排序服务
        - 生成 channel configuration transaction
            - 用来配置和创建 channel 的配置文件
        - 生成组织锚节点 anchor peer transactions

    :configtxlator:
    :cryptogen:

        - 根据网络用户拓扑关系（ .yaml 文件定义 ）生成各个节点（ peers,orderers,ca ）的证书
        - 生产环境中应该由每个 org 的 CA 节点颁发

    :peer:


基础镜像
------------

:fabric-baseos:    基于 ubuntu:xenial ，用来生成 peer、orderer、ca 以及 Golang链码容器等镜像
:fabric-baseimage: 基于 fabric-baseos ，安装了 JDK、Golang、Node、protocol buffer 等，用来生成其他镜像
:链码基础镜像: 基于 fabric-baseimage ，在链码容器生成过程中作为编译环境将链码编译为二进制文件，供链码容器使用，方便保持链码容器自身的轻量化

    :fabric-ccenv:   安装了 chaintool、Go 语言的链码 shim 层等，用来生成 Go 语言的链码执行环境镜像
    :fabric-javaenv: 安装了 Gradle、Maven、Java 链码 shim 层等，用来生成 Java 链码执行环境镜像

:辅助服务镜像: 基于 fabric-baseimage

    :fabric-couchdb:   启动 couchdb 服务，供 peer 使用
    :fabric-kafka:     启动 kafka 服务，供 orderer 使用
    :fabric-zookeeper: 启动 zookeeper 服务，供 orderer 的 kafka 使用


peer channel
-------------
- channel 存在于 orderer 结点内部，但需要使用 ``peer channel`` 命令进行维护
- 两个 peer 结点必须同时处在同一个 channel 中，才能发生交易

:peer channel create:       在 orderer 内部创建一个 channel （每个 channel 执行一次）
:peer channel join:         把 peer 加入一个 channel （每个 peer 执行一次）
:peer channel update:       升级 channel 的某一组织的锚节点配置（每个组织执行一次）
:peer channel fetch config: 获取 channel 中 newest/oldest 块数据或当前最新的配置数据
:peer channel list:         列出当前系统中已经存在的 channel


peer chaincode
---------------

:peer chaincode install:     初始化，给需要参与交易的 peer 安装链码（将 chaincode 放到 peer 的文件系统的过程）
:peer chaincode instantiate: 实例化链码（给每个 peer 创建并启动 1 个链码容器，其他 peer 节点会同步链码信息）
:peer chaincode upgrade:     升级链码
:peer chaincode package:     打包链码
:peer chaincode signpackage: 对打包文件进行签名
:peer chaincode query:       对于 world state 中某个 key 的 value 的查询请求
:peer chaincode invoke:      调用 chaincode 内的函数，处理交易提案


智能合约
--------------
- 本质是注册存储到链上的一段逻辑代码
- Fabric 的智能合约称为链码，分为系统链码和用户链码
    - 系统链码(SCC)
        - LSCC(Lifecycle system chaincode)
            - 处理有关生命周期（一个 ``用户链码`` 的安装、实例化、升级、卸载等）的请求
        - CSCC(Configuration system chaincode)
            - 处理在 peer 程序端的 channel 配置
        - QSCC(Query system chaincode)
            - 提供账本查询接口，如获取块和交易信息
        - ESCC(Endorsement system chaincode)
            - 通过对交易申请的应答信息进行签名，来提供背书功能
        - VSCC(Validation system chaincode)
            - 处理交易校验，包括检查背书策略和版本在并发时的控制
    - 用户链码(ACC)
        - 单独运行在一个 Docker 容器中，用来实现用户的应用功能
        - 在链码部署的时候会自动生成 Docker 镜像
        - 支持采用 Go、Java、Nodejs 编写，并提供相应的中间层供链码使用
        - 可以使用 GetState 和 PutState 接口和 Peer 节点通信，存取 K-V 数据


msp
----
- MSP 只是一个接口，Fabric-CA 是 MSP 接口的一种实现，是默认的证书管理组件
    - 向网络成员及其用户颁发基于 PKI 的数字证书
    - 为每个成员颁发一个根证书（rCert），为每个授权用户颁发一个注册证书（eCert），为每个注册证书颁发大量交易证书（tCerts）
    - 每个 MSP 只有一个根 CA 证书 ，从 rCert 到 eCert 形成一个证书信任链

        :根CA证书: 自签名的证书，用 rCert 签名生成的证书可以签发新的证书，形成树型结构 （必须配置）
        :中间CA证书: （Intermediate Certificate）由其他 CA 证书签发的证书，可以利用自己的私钥签发新的证书 （可选配置）
        :MSP管理员证书: 有根CA的证书路径，有权限修改channel配置 （必须配置，创建、加入 channel 等请求都需要管理员私钥进行签名）
        :TLS根CA证书: 自签名的证书，用于 TLS（Transport Layer Security, 安全传输层协议）传输 （必须配置）

- Fabirc 的成员身份基于标准的 X.509 证书，密钥使用 ECDSA 算法，通道内只有相同 MSP 内的节点才可以通过 Gossip 协议进行数据分发