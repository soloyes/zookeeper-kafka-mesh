#!/usr/bin/env bash
# Rewrite the zoo.cfg server list on one ZooKeeper container and restart it.
# $1 - Container ID
# $2 - Container type (zookeeper)
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
. ./functions

if [[ -z "$1" || "$2" != zookeeper ]]; then
    log ERROR "Usage: $0 ContainerID zookeeper"
    exit 1
fi

PushZoo "$1"
