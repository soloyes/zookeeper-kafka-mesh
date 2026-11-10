#!/usr/bin/env bash
# Tear the mesh down: remove every container on our network, the network and the state files.
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
. ./functions

log STARS
log WARN "Clear all configuration with Clear.sh"

if [ -f NetName ]; then
    NET=$(net_name)
    containers=$(docker ps -aq --filter "network=$NET")
    if [ -n "$containers" ]; then
        # shellcheck disable=SC2086 # one id per word
        docker rm -f $containers >/dev/null
        log INFO "Removed containers: $(echo "$containers" | tr '\n' ' ')"
    fi
    if docker network rm "$NET" >/dev/null; then
        log INFO "Removed network $NET"
    else
        log ERROR "Could not remove network $NET"
    fi
    rm -f NetName zookeeperIP kafkaIP zookeeper_myid kafka_myid
else
    log ERROR "There is no network, please create it using init.sh"
fi

log STARS
log INFO "Exit Clear.sh"
