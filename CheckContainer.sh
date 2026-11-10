#!/usr/bin/env bash
# Look at the running zookeeper/kafka containers of the mesh, rebuild the state
# files from them and ask whether to create more / delete one.
# Exit code: 0 = go on (create/delete), 1 = skip.
# $1 - Container type (zookeeper/kafka)
# $2 - create/delete
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
. ./functions

if [[ "$1" != kafka && "$1" != zookeeper ]] || [[ "$2" != create && "$2" != delete ]]; then
    log ERROR "Usage: $0 (zookeeper/kafka) (create/delete)"
    exit 1
fi

# Rebuild $1IP and the id counter from what is really running: containers may
# have been stopped by hand since the last run.
refresh_state "$1"
Containers=$(grep -c . "$1IP")

if is_noninteractive; then
    exit 0
fi

if [ "$Containers" -eq 0 ] && [ "$2" = delete ]; then
    exit 1
elif [ "$Containers" -eq 0 ] && [ "$1" = kafka ]; then
    log WARN "There are no $1 nodes, create?"
    selectYN
elif [ "$Containers" -eq 0 ] && [ "$1" = zookeeper ]; then
    # At least one zookeeper must exist: init.sh goes on to CreateContainer.sh zookeeper.
    log INFO "There are no $1 nodes. Creating..."
    exit 0
else
    docker ps --filter "network=$(net_name)" --filter "ancestor=baseimage-$1"
    log WARN "There are $Containers $1 nodes above, $([ "$2" = create ] && echo 'create more?' || echo 'delete one?')"
    selectYN
fi
