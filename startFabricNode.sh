#!/bin/bash
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

#
# This script builds the docker compose file needed to run this sample.
#

set -e

SDIR=$(dirname "$0")
source ${SDIR}/scripts/env.sh

cd ${SDIR}

function help {
    echo "Usage:

    $0 run

    ENV:
    ORDERER_ORGS
    PEER_ORGS
    NUM_PEERS
    NUM_ORDERERS
    CHANNEL_NAME
    USE_INTERMEDIATE_CA
    # CouchDB
    USE_STATE_DATABASE_COUCHDB
    COUCHDB_USER
    COUCHDB_PASSWORD
    # Kafka consensus
    USE_CONSENSUS_KAFKA
    NUM_KAFKA
    # Explorer
    USE_BLOCKCHAIN_EXPLORER
    "
    exit 1
}

if [ $# -le 0 ]; then
    help
fi

function RunExplorer {
    if [ $FABRIC_VERSION  == "1.2.0" ]; then
        ${SDIR}/makeExplorer1.2.sh
    fi

    if [ $FABRIC_VERSION  == "1.1.0" ]; then
        ${SDIR}/makeExplorer1.1.sh
    fi

    docker-compose -p net -f docker-compose.yml up -d explorer-db
    sleep 2
    docker exec  explorer-db psql -h localhost -U postgres -c "CREATE USER $DATABASE_USERNAME WITH PASSWORD '$DATABASE_PASSWD'"
    docker exec  explorer-db psql -h localhost -U postgres  -a -f /opt/explorerpg.sql >/dev/null 2>&1
    docker exec  explorer-db psql -h localhost -U postgres  -a -f /opt/updatepg.sql >/dev/null 2>&1
    docker-compose -p net -f docker-compose.yml up -d explorer
    log "Explorer start success. http://localhost:8081"
}

IFS=', ' read -r -a PORGS <<< "$PEER_ORGS"
if [ ${#PORGS[*]} -le 1 ]; then
    fatal "Peer organization at least two，change PEER_ORGS ENV."
fi

# Delete docker containers
dockerContainers=$(docker ps -a | awk '$2~/hyperledger/ {print $1}')
if [ "$dockerContainers" != "" ]; then
   log "Deleting existing docker containers ..."
   docker rm -f $dockerContainers > /dev/null
fi

# Remove chaincode docker images
chaincodeImages=`docker images | grep "^dev-peer" | awk '{print $3}'`
if [ "$chaincodeImages" != "" ]; then
   log "Removing chaincode docker images ..."
   docker rmi -f $chaincodeImages > /dev/null
fi


log "Orderer Org: $ORDERER_ORGS"
log "Num Orderer: $NUM_ORDERERS"
log "Peer Org: $PEER_ORGS"
log "Num Peer: $NUM_PEERS"
log "Use CouchDB: $USE_STATE_DATABASE_COUCHDB"
log "Use Kafka: $USE_CONSENSUS_KAFKA"
log "Use Explorer: $USE_BLOCKCHAIN_EXPLORER"
# Judge the docker-compose file
if [ ! -f ${SDIR}/docker-compose.yml ]; then
    ${SDIR}/makeDocker.sh
    mkdir -p $SDIR/data/logs
fi

# Create the docker containers
log "Creating docker containers ..."
docker-compose -p net -f docker-compose.yml up -d $*

# Wait for the setup container to complete
dowait "the 'setup' container to finish registering identities, creating the genesis block and other artifacts" 90 $SDIR/$SETUP_LOGFILE $SDIR/$SETUP_SUCCESS_FILE

# Wait for the run container to start and then tails it's summary log
dowait "the docker 'run' container to start" 60 ${SDIR}/${SETUP_LOGFILE} ${SDIR}/${RUN_SUMFILE}
tail -f ${SDIR}/${RUN_SUMFILE}&
TAIL_PID=$!

# Wait for the run container to complete
while true; do 
   if [ -f ${SDIR}/${RUN_SUCCESS_FILE} ]; then
      kill -9 $TAIL_PID
      if $USE_BLOCKCHAIN_EXPLORER; then
        RunExplorer
      fi
      exit 0
   elif [ -f ${SDIR}/${RUN_FAIL_FILE} ]; then
      kill -9 $TAIL_PID
      exit 1
   else
      sleep 1
   fi
done
