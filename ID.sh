#!/usr/bin/env bash
# Hand out (create) or give back (delete) the next ZooKeeper myid / Kafka broker.id.
# The counter lives in $1_myid. Nodes are always removed newest first, so a plain
# counter is enough; CheckContainer.sh resyncs it with the running containers.
# $1 - Container type (zookeeper/kafka)
# $2 - operation (create/delete)
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
. ./functions

if [[ "$1" != kafka && "$1" != zookeeper ]] || [[ "$2" != create && "$2" != delete ]]; then
    log ERROR "Usage: $0 (zookeeper/kafka) (create/delete)"
    exit 1
fi

current=$(cat "$1_myid" 2>/dev/null)
[[ "$current" =~ ^[0-9]+$ ]] || current=0

if [ "$2" = create ]; then
    echo $((current + 1)) >"$1_myid"
elif [ "$current" -gt 0 ]; then
    echo $((current - 1)) >"$1_myid"
fi

log INFO_s "$1_myid contains: $(cat "$1_myid")"
