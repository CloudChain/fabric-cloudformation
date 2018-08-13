#!/bin/bash
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

#
# This script builds the docker compose file needed to run this sample.
#

SDIR=$(dirname "$0")
source $SDIR/scripts/env.sh

function main {
   {
   writeHeader
   writeRootFabricCA
   if $USE_INTERMEDIATE_CA; then
      writeIntermediateFabricCA
   fi
   if $USE_CONSENSUS_KAFKA; then
      writeKafkaZK
   fi
   writeSetupFabric
   writeStartFabric
   writeRunFabric

   if $USE_BLOCKCHAIN_EXPLORER; then
      writeExplorer
      writeExplorerDB
   fi
   } > $SDIR/docker-compose.yml
   log "Created docker-compose.yml"
}

# Write services for the root fabric CA servers
function writeRootFabricCA {
   for ORG in $ORGS; do
      initOrgVars $ORG
      writeRootCA
   done
}

# Write services for the intermediate fabric CA servers
function writeIntermediateFabricCA {
   for ORG in $ORGS; do
      initOrgVars $ORG
      writeIntermediateCA
   done
}


# Write services for the kafka and zookeeper
function writeKafkaZK {
  for (( k=1; k<=$NUM_KAFKA; k++ )); do
    initKafkaVars $k
    writeKafka
  done

 for (( z=1; z<=$NUM_ZOOKEEPER; z++ )); do
    initZKVars $z
    writeZooKeeper $z
  done
}

function writeKafka {
  KAFKA_ZOOKEEPER_CONNECT=()
  for (( i=1; i<=$NUM_ZOOKEEPER; i++ )); do
    initZKVars $i
    if [ $i -eq $NUM_ZOOKEEPER ];then
      KAFKA_ZOOKEEPER_CONNECT[$i]=$ZOO_NAME:2181
    else
      KAFKA_ZOOKEEPER_CONNECT[$i]=$ZOO_NAME:2181,
    fi
  done
 echo "  $KAFKA_NAME:
    container_name: $KAFKA_NAME
    image: hyperledger/fabric-kafka
    environment:
      - KAFKA_BROKER_ID=$KAFKA_BROKER_ID
      - KAFKA_ZOOKEEPER_CONNECT=${KAFKA_ZOOKEEPER_CONNECT[@]}
      - KAFKA_LOG_RETENTION_MS=-1
      - KAFKA_MESSAGE_MAX_BYTES=103809024
      - KAFKA_REPLICA_FETCH_MAX_BYTES=103809024
      - KAFKA_UNCLEAN_LEADER_ELECTION_ENABLE=false
      - KAFKA_MIN_INSYNC_REPLICAS=$KAFKA_MIN_INSYNC_REPLICAS
      - KAFKA_DEFAULT_REPLICATION_FACTOR=$KAFKA_DEFAULT_REPLICATION_FACTOR
    networks:
      - $NETWORK
    depends_on:"
   for (( i=1; i<=$NUM_ZOOKEEPER; i++ )); do
      initZKVars $i
      echo "      - $ZOO_NAME"
   done
}

function writeZooKeeper {
  local num=$1
  ZOO_SERVERS=()
  for (( i=1; i<=$NUM_ZOOKEEPER; i++ )); do
      initZKVars $i
      ZOO_SERVERS[$i]=server.$i=$ZOO_NAME:2888:3888
  done

  initZKVars $num
  echo "  $ZOO_NAME:
    container_name: $ZOO_NAME
    image: hyperledger/fabric-zookeeper
    environment:
      - ZOO_MY_ID=$ZOO_MY_ID
      - ZOO_SERVERS=${ZOO_SERVERS[@]}
    networks:
      - $NETWORK"
}

# Write a service to setup the fabric artifacts (e.g. genesis block, etc)
function writeSetupFabric {
   echo "  setup:
    container_name: setup
    image: hyperledger/fabric-ca-tools
    command: /bin/bash -c '/scripts/setup-fabric.sh 2>&1 | tee /$SETUP_LOGFILE; sleep 99999'
    environment:
      - ORDERER_ORGS="$ORDERER_ORGS"
      - PEER_ORGS="$PEER_ORGS"
      - NUM_PEERS=$NUM_PEERS
      - NUM_ORDERERS=$NUM_ORDERERS
      - CHANNEL_NAME=$CHANNEL_NAME
      - USE_INTERMEDIATE_CA=$USE_INTERMEDIATE_CA
      - USE_CONSENSUS_KAFKA=$USE_CONSENSUS_KAFKA
      - NUM_KAFKA=$NUM_KAFKA
      - NUM_ZOOKEEPER=$NUM_ZOOKEEPER
    volumes:
      - ./scripts:/scripts
      - ./$DATA:/$DATA
    networks:
      - $NETWORK
    depends_on:"
   for ORG in $ORGS; do
      initOrgVars $ORG
      echo "      - $CA_NAME"
   done
   echo ""
}

# Write services for fabric orderer and peer containers
function writeStartFabric {
   for ORG in $ORDERER_ORGS; do
      COUNT=1
      while [[ "$COUNT" -le $NUM_ORDERERS ]]; do
         initOrdererVars $ORG $COUNT
         writeOrderer
         COUNT=$((COUNT+1))
      done
   done
   for ORG in $PEER_ORGS; do
      COUNT=1
      while [[ "$COUNT" -le $NUM_PEERS ]]; do
         initPeerVars $ORG $COUNT
         if $USE_STATE_DATABASE_COUCHDB; then
            writeCouchDB
         fi
         writePeer
         COUNT=$((COUNT+1))
      done
   done
}

# Write a service to run a fabric test including creating a channel,
# installing chaincode, invoking and querying
function writeRunFabric {
   # Set fabric directory relative to GOPATH
   FABRIC_DIR=${GOPATH}/src/github.com/hyperledger/fabric
   echo "  run:
    container_name: run
    image: hyperledger/fabric-ca-tools
    environment:
      - GOPATH=/opt/gopath
      - ORDERER_ORGS="$ORDERER_ORGS"
      - PEER_ORGS="$PEER_ORGS"
      - NUM_PEERS=$NUM_PEERS
      - NUM_ORDERERS=$NUM_ORDERERS
      - CHANNEL_NAME=$CHANNEL_NAME
      - USE_INTERMEDIATE_CA=$USE_INTERMEDIATE_CA
    command: /bin/bash -c 'sleep 3;/scripts/run-fabric.sh 2>&1 | tee /$RUN_LOGFILE; sleep 99999'
    volumes:
      - ./scripts:/scripts
      - ./$DATA:/$DATA
      - ./:/opt/gopath/src/github.com/hyperledger/fabric-samples
      - ${FABRIC_DIR}:/opt/gopath/src/github.com/hyperledger/fabric
    networks:
      - $NETWORK
    depends_on:"
   for ORG in $ORDERER_ORGS; do
      COUNT=1
      while [[ "$COUNT" -le $NUM_ORDERERS ]]; do
         initOrdererVars $ORG $COUNT
         echo "      - $ORDERER_NAME"
         COUNT=$((COUNT+1))
      done
   done
   for ORG in $PEER_ORGS; do
      COUNT=1
      while [[ "$COUNT" -le $NUM_PEERS ]]; do
         initPeerVars $ORG $COUNT
         echo "      - $PEER_NAME"
         COUNT=$((COUNT+1))
      done
   done
}

function writeRootCA {
   echo "  $ROOT_CA_NAME:
    container_name: $ROOT_CA_NAME
    image: hyperledger/fabric-ca
    command: /bin/bash -c '/scripts/start-root-ca.sh 2>&1 | tee /$ROOT_CA_LOGFILE'
    environment:
      - FABRIC_CA_SERVER_HOME=/etc/hyperledger/fabric-ca
      - FABRIC_CA_SERVER_TLS_ENABLED=true
      - FABRIC_CA_SERVER_CSR_CN=$ROOT_CA_NAME
      - FABRIC_CA_SERVER_CSR_HOSTS=$ROOT_CA_HOST
      - FABRIC_CA_SERVER_DEBUG=true
      - BOOTSTRAP_USER_PASS=$ROOT_CA_ADMIN_USER_PASS
      - TARGET_CERTFILE=$ROOT_CA_CERTFILE
      - FABRIC_ORGS="$ORGS"
      - ORDERER_ORGS="$ORDERER_ORGS"
      - PEER_ORGS="$PEER_ORGS"
      - NUM_PEERS=$NUM_PEERS
      - NUM_ORDERERS=$NUM_ORDERERS
      - CHANNEL_NAME=$CHANNEL_NAME
      - USE_INTERMEDIATE_CA=$USE_INTERMEDIATE_CA
    volumes:
      - ./scripts:/scripts
      - ./$DATA:/$DATA
    networks:
      - $NETWORK
"
}

function writeIntermediateCA {
   echo "  $INT_CA_NAME:
    container_name: $INT_CA_NAME
    image: hyperledger/fabric-ca
    command: /bin/bash -c '/scripts/start-intermediate-ca.sh $ORG 2>&1 | tee /$INT_CA_LOGFILE'
    environment:
      - FABRIC_CA_SERVER_HOME=/etc/hyperledger/fabric-ca
      - FABRIC_CA_SERVER_CA_NAME=$INT_CA_NAME
      - FABRIC_CA_SERVER_INTERMEDIATE_TLS_CERTFILES=$ROOT_CA_CERTFILE
      - FABRIC_CA_SERVER_CSR_HOSTS=$INT_CA_HOST
      - FABRIC_CA_SERVER_TLS_ENABLED=true
      - FABRIC_CA_SERVER_DEBUG=true
      - BOOTSTRAP_USER_PASS=$INT_CA_ADMIN_USER_PASS
      - PARENT_URL=https://$ROOT_CA_ADMIN_USER_PASS@$ROOT_CA_HOST:7054
      - TARGET_CHAINFILE=$INT_CA_CHAINFILE
      - ORG=$ORG
      - FABRIC_ORGS="$ORGS"
      - ORDERER_ORGS="$ORDERER_ORGS"
      - PEER_ORGS="$PEER_ORGS"
      - NUM_PEERS=$NUM_PEERS
      - NUM_ORDERERS=$NUM_ORDERERS
      - CHANNEL_NAME=$CHANNEL_NAME
      - USE_INTERMEDIATE_CA=$USE_INTERMEDIATE_CA
    volumes:
      - ./scripts:/scripts
      - ./$DATA:/$DATA
    networks:
      - $NETWORK
    depends_on:
      - $ROOT_CA_NAME
"
}

function writeOrderer {
   MYHOME=/etc/hyperledger/orderer
   echo "  $ORDERER_NAME:
    container_name: $ORDERER_NAME
    image: hyperledger/fabric-ca-orderer
    environment:
      - FABRIC_CA_CLIENT_HOME=$MYHOME
      - FABRIC_CA_CLIENT_TLS_CERTFILES=$CA_CHAINFILE
      - ENROLLMENT_URL=https://$ORDERER_NAME_PASS@$CA_HOST:7054
      - ORDERER_HOME=$MYHOME
      - ORDERER_NAME=$ORDERER_NAME
      - ORDERER_HOST=$ORDERER_HOST
      - ORDERER_GENERAL_LISTENADDRESS=0.0.0.0
      - ORDERER_GENERAL_GENESISMETHOD=file
      - ORDERER_GENERAL_GENESISFILE=$GENESIS_BLOCK_FILE
      - ORDERER_GENERAL_LOCALMSPID=$ORG_MSP_ID
      - ORDERER_GENERAL_LOCALMSPDIR=$MYHOME/msp
      - ORDERER_GENERAL_TLS_ENABLED=true
      - ORDERER_GENERAL_TLS_PRIVATEKEY=$MYHOME/tls/server.key
      - ORDERER_GENERAL_TLS_CERTIFICATE=$MYHOME/tls/server.crt
      - ORDERER_GENERAL_TLS_ROOTCAS=[$CA_CHAINFILE]
      - ORDERER_GENERAL_TLS_CLIENTAUTHREQUIRED=false
      - ORDERER_GENERAL_TLS_CLIENTROOTCAS=[$CA_CHAINFILE]
      - ORDERER_GENERAL_LOGLEVEL=debug
      - ORDERER_DEBUG_BROADCASTTRACEDIR=$LOGDIR
      - ORG=$ORG
      - ORG_ADMIN_CERT=$ORG_ADMIN_CERT
      - ORDERER_ORGS="$ORDERER_ORGS"
      - PEER_ORGS="$PEER_ORGS"
      - NUM_PEERS=$NUM_PEERS
      - NUM_ORDERERS=$NUM_ORDERERS
      - CHANNEL_NAME=$CHANNEL_NAME
      - USE_INTERMEDIATE_CA=$USE_INTERMEDIATE_CA"
  if $USE_CONSENSUS_KAFKA; then
    KAFKA_BROKERS=()
    for (( i=1; i<=$NUM_KAFKA; i++ )); do
      initKafkaVars $i
      if [ $i -eq $NUM_KAFKA ];then
        KAFKA_BROKERS[$i]=$KAFKA_NAME:9092
      else
        KAFKA_BROKERS[$i]=$KAFKA_NAME:9092,
      fi
    done
  echo "      - ORDERER_KAFKA_RETRY_SHORTINTERVAL=1s
      - ORDERER_KAFKA_RETRY_SHORTTOTAL=30s
      - ORDERER_KAFKA_VERBOSE=true
      - ORDERER_GENERAL_GENESISPROFILE=SampleInsecureKafka
      - CONFIGTX_ORDERER_ORDERERTYPE=kafka
      - CONFIGTX_ORDERER_KAFKA_BROKERS=[${KAFKA_BROKERS[@]}]"
  fi
  echo "    command: /bin/bash -c '/scripts/start-orderer.sh 2>&1 | tee /$ORDERER_LOGFILE'
    volumes:
      - ./scripts:/scripts
      - ./$DATA:/$DATA
    networks:
      - $NETWORK
    depends_on:
      - setup"
  if $USE_CONSENSUS_KAFKA; then
  KAFKA_BROKERS=()
  for (( k=1; k<=$NUM_KAFKA; k++ )); do
      initKafkaVars $k
      echo "      - $KAFKA_NAME"
    done
  fi
}

function writePeer {
   MYHOME=/opt/gopath/src/github.com/hyperledger/fabric/peer
   echo "  $PEER_NAME:
    container_name: $PEER_NAME
    image: hyperledger/fabric-ca-peer
    environment:
      - FABRIC_CA_CLIENT_HOME=$MYHOME
      - FABRIC_CA_CLIENT_TLS_CERTFILES=$CA_CHAINFILE
      - ENROLLMENT_URL=https://$PEER_NAME_PASS@$CA_HOST:7054
      - PEER_NAME=$PEER_NAME
      - PEER_HOME=$MYHOME
      - PEER_HOST=$PEER_HOST
      - PEER_NAME_PASS=$PEER_NAME_PASS
      - CORE_PEER_ID=$PEER_HOST
      - CORE_PEER_ADDRESS=$PEER_HOST:7051
      - CORE_PEER_LOCALMSPID=$ORG_MSP_ID
      - CORE_PEER_MSPCONFIGPATH=$MYHOME/msp
      - CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
      - CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=net_${NETWORK}
      - CORE_LOGGING_LEVEL=DEBUG
      - CORE_PEER_TLS_ENABLED=true
      - CORE_PEER_TLS_CERT_FILE=$MYHOME/tls/server.crt
      - CORE_PEER_TLS_KEY_FILE=$MYHOME/tls/server.key
      - CORE_PEER_TLS_ROOTCERT_FILE=$CA_CHAINFILE
      - CORE_PEER_TLS_CLIENTAUTHREQUIRED=false
      - CORE_PEER_TLS_CLIENTROOTCAS_FILES=$CA_CHAINFILE
      - CORE_PEER_TLS_CLIENTCERT_FILE=/$DATA/tls/$PEER_NAME-client.crt
      - CORE_PEER_TLS_CLIENTKEY_FILE=/$DATA/tls/$PEER_NAME-client.key
      - CORE_PEER_GOSSIP_USELEADERELECTION=true
      - CORE_PEER_GOSSIP_ORGLEADER=false
      - CORE_PEER_GOSSIP_EXTERNALENDPOINT=$PEER_HOST:7051
      - CORE_PEER_GOSSIP_SKIPHANDSHAKE=true
      - ORG=$ORG
      - ORDERER_ORGS="$ORDERER_ORGS"
      - PEER_ORGS="$PEER_ORGS"
      - NUM_PEERS=$NUM_PEERS
      - NUM_ORDERERS=$NUM_ORDERERS
      - CHANNEL_NAME=$CHANNEL_NAME
      - USE_INTERMEDIATE_CA=$USE_INTERMEDIATE_CA
      - ORG_ADMIN_CERT=$ORG_ADMIN_CERT"
   if $USE_STATE_DATABASE_COUCHDB; then
      echo "      - CORE_LEDGER_STATE_STATEDATABASE=CouchDB
      - CORE_LEDGER_STATE_COUCHDBCONFIG_COUCHDBADDRESS=$COUCHDB_NAME:5984
      - CORE_LEDGER_STATE_COUCHDBCONFIG_USERNAME=$COUCHDB_USER
      - CORE_LEDGER_STATE_COUCHDBCONFIG_PASSWORD=$COUCHDB_PASSWORD
      "
   fi
   if [ $NUM -gt 1 ]; then
      echo "      - CORE_PEER_GOSSIP_BOOTSTRAP=peer1-${ORG}:7051"
   fi
   echo "    working_dir: $MYHOME
    command: /bin/bash -c '/scripts/start-peer.sh 2>&1 | tee /$PEER_LOGFILE'
    volumes:
      - ./scripts:/scripts
      - ./$DATA:/$DATA
      - /var/run:/host/var/run
    networks:
      - $NETWORK
    depends_on:
      - setup"
  if $USE_STATE_DATABASE_COUCHDB; then
  echo "      - $COUCHDB_NAME"
  fi
}

function writeCouchDB {
   echo "  $COUCHDB_NAME:
    container_name: $COUCHDB_NAME
    image: hyperledger/fabric-couchdb
    environment:
      - COUCHDB_USER=$COUCHDB_USER
      - COUCHDB_PASSWORD=$COUCHDB_PASSWORD
    networks:
      - $NETWORK
"
}

function writeExplorer {
   echo "  $EXPLORER_NAME:
    container_name: $EXPLORER_NAME
    image: lisuo/fabric-explorer
    environment:
      - DATABASE_HOST=$EXPLORER_DB_NAME
      - DATABASE_PORT=$DATABASE_PORT
      - DATABASE_NAME=$DATABASE_NAME
      - DATABASE_USERNAME=$DATABASE_USERNAME
      - DATABASE_PASSWD=$DATABASE_PASSWD
    volumes:
      - ./$DATA:/$DATA"
      if [ $FABRIC_VERSION == "1.2.0" ]; then
        echo "      - ./config.json:/opt/explorer/app/platform/fabric/config_1.2.0.json"
      fi
      if [ $FABRIC_VERSION == "1.1.0" ]; then
        echo "      - ./config.json:/opt/explorer/app/platform/fabric/config.json"
      fi
      echo "      - ./appconfig.json:/opt/explorer/appconfig.json
      - ./pgconfig.json:/opt/explorer/app/persistence/postgreSQL/db/pgconfig.json
    networks:
      - $NETWORK
    ports:
      - \"8080:8080\"
    depends_on:
      - $EXPLORER_DB_NAME
"
}

function writeExplorerDB {
   echo "  $EXPLORER_DB_NAME:
    container_name: $EXPLORER_DB_NAME
    image: lisuo/fabric-explorer-db
    environment:
      - USER=$DATABASE_USERNAME
      - DATABASE=$DATABASE_NAME
      - PASSWD=$DATABASE_PASSWD
    volumes:
      - ./$DATA:/$DATA
    networks:
      - $NETWORK
"
}

function writeHeader {
   echo "version: '2.1'

networks:
  $NETWORK:

services:
"
}

main
