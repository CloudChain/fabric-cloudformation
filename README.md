# Hyperledger Fabric 多主机部署

使用docker swarm 集群模式部署Fabric网络

## 功能

* 自定义组织
* Kafka 共识方式
* CouchDB 状态数据库
* CA 证书管理



## 前提

* 所有参与Fabric 网络节点使用共享目录



## 使用

```shell
cd 共享目录
git clone https://github.com/lisuo3389/fabric-cloudformation.git

# 所有参与fabric 节点都要执行
./preRequisites.sh 

# 指定swarm 节点类型 `manager` `worker`
# 在不同类型的swarm节点上执行
./initDockerSwarm.sh 

# 在不同服务类型节点上执行
startFabricNode.sh # 服务名称
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
```





