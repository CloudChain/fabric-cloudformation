set -e

SDIR=$(dirname "$0")
source ${SDIR}/scripts/env.sh

cd ${SDIR}

# Judge the docker-compose file
if [ ! -f ${SDIR}/docker-compose.yml ]; then
    fatal "Can't found $*"
fi

# Create the docker containers
log "Stoping docker containers ..."
docker-compose -p net -f docker-compose.yml down
rm -fr data docker-compose.yml
docker rm -f $(docker ps -aq --filter name=dev-peer)
docker rmi $(docker images | awk '$1 ~ /dev-peer/ { print $3 }')