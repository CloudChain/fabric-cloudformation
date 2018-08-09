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
    "
    exit 1
}

if [ $# -le 0 ]; then
    help
fi


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
      exit 0
   elif [ -f ${SDIR}/${RUN_FAIL_FILE} ]; then
      kill -9 $TAIL_PID
      exit 1
   else
      sleep 1
   fi
done
