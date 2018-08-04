set -e

SDIR=$(dirname "$0")
source ${SDIR}/scripts/env.sh

cd ${SDIR}

# Start with a clean data directory
DDIR=${SDIR}/${DATA}
if [ -d ${DDIR} ]; then
   log "Cleaning up the data directory from previous run at $DDIR"
   rm -rf ${SDIR}/data
fi
mkdir -p ${DDIR}/logs

# Judge the docker-compose file
if [ ! -f ${SDIR}/docker-complete.yml ]; then
    ${SDIR}/makeDocker.sh
fi

# Create the docker containers
log "Creating docker containers ..."
docker-compose up -d $1
