set -e

SDIR=$(dirname "$0")
source ${SDIR}/scripts/env.sh

cd ${SDIR}

function help {
    echo "Usage:

    $0 setup|orderer{Number}-{OrgName}|peer{Number}-{OrgName}|run

    Example: 
    $0 setup - Setup Org CA
    $0 orderer1-org1 - Start org1 orderer1 node

    *The {Number} begin at 1*

    Options:
    setup - Setup Org CA
    orderer - Start fabric network orderer node
    peer - Start fabric network peer node
    run - Run test fabric network

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

# Judge the docker-compose file
if [ ! -f ${SDIR}/docker-compose.yml ]; then
    fatal "Can't found $*"
fi

# Create the docker containers
log "Stoping docker containers ..."
docker-compose -p net -f docker-compose.yml down
