set -e
SDIR=$(dirname "$0")
source $SDIR/scripts/env.sh

log "Stopping docker containers ..."
docker-compose down $1
log "Docker containers have been stopped"