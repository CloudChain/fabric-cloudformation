# Hyperledger Fabric 测试环境

使用docker及docker-compose 自动部署

## 功能

* 自定义组织
* Kafka 共识方式
* CouchDB 状态数据库
* CA 证书管理


## 使用

```shell
cd 共享目录
git clone https://github.com/lisuo3389/fabric-cloudformation.git

# 初始化安装
./preRequisites.sh 

# 启动Fabric 网络
startFabricNode.sh run
```

**Fabric 配置系统环境变量**

```shell
# orderer 组织名称，可以多个，使用空格分隔
export ORDERER_ORGS="OrdererOrg"
# peer 组织名称，可以多个，使用空格分隔
export PEER_ORGS="PeerOrg1 PeerOrg2"
# 每个peer组织的peer 节点数量
export NUM_PEERS=2
# 每个orderer 组织的orderer节点数量
export NUM_ORDERERS=1 
# channel 名称
export CHANNEL_NAME="testchannel"
# 是否使用中间ca
export USE_INTERMEDIATE_CA=true

# CouchDB
export USE_STATE_DATABASE_COUCHDB=true
export COUCHDB_USER
export COUCHDB_PASSWORD
# Kafka consensus
export USE_CONSENSUS_KAFKA=true
export NUM_KAFKA=4

# Explorer
export USE_BLOCKCHAIN_EXPLORER=true
```





