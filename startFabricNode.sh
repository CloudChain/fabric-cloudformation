set -e

SDIR=$(dirname "$0")
source ${SDIR}/scripts/env.sh

cd ${SDIR}

function help {
    echo "Usage:

    $0 setup|orderer{Number}-{OrgName}|peer{Number}-{OrgName}|couchdb|kafka|run|all

    Example: 
    $0 setup - Setup Org CA
    $0 orderer1-org1 - Start org1 orderer1 node

    Options:
    setup - Setup Org CA
    orderer - Start fabric network orderer node
    peer - Start fabric network peer node
    couchdb - Start couchdb state database
    kafka - Start kafka consensus
    run - Run test fabric network
    all - Start all fabric node
    "
    exit 1
}

if [ $# -le 0 ]; then
    help
fi

# Judge the docker-compose file
if [ ! -f ${SDIR}/docker-compose.yml ]; then
    ${SDIR}/makeDocker.sh
fi

# Create the docker containers
log "Creating docker containers ..."
docker-compose -p net -f docker-compose.yml up -d $1
