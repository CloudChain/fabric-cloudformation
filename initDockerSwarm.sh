set -e

SDIR=$(dirname "$0")
source $SDIR/scripts/env.sh

# initDockerSwarm Help 
function help {
    echo "Usage: 
    $0 manager|worker

    Options:
    manager - Docker swarm manager node.
    worker - Docker swarm worker node.
    "
    exit 1
}

if [ $# -le 0 ]; then
    help
fi

if [ ! -f ${DOCKER_SWARM_INIT} ]; then
    log "Init docker swarm"
    docker swarm init && \
    docker swarm join-token manager | grep "docker"|sed 's/^ *//' > ${DOCKER_SWARM_MANAGER} && \
    docker swarm join-token worker | grep "docker"|sed 's/^ *//' > ${DOCKER_SWARM_WORKER}
    if [ $? -ne 0 ]; then
        fatal "Docker swarm init failure."
    fi
    touch ${DOCKER_SWARM_INIT}
    log "Join docker swarm cluster $1"
    exit 0
fi

case $1 in 
manager)
    log "Join docker swarm cluster $1"
    sh ${DOCKER_SWARM_MANAGER}
    ;;
worker)
    log "Join docker swarm cluster $1"
    sh ${DOCKER_SWARM_WORKER}
    ;;
*)
    help
    ;;
esac