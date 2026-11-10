#!/usr/bin/env bash
# Point one Kafka broker at every ZooKeeper node (zookeeper.connect in server.properties).
# $1 - Container ID
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
. ./functions

if [ -z "$1" ]; then
    log ERROR "Usage: $0 ContainerID"
    exit 1
fi

zookeeperconnect=""
while read -r ip _; do
    [ -n "$ip" ] && zookeeperconnect="${zookeeperconnect}${ip}:2181,"
done <zookeeperIP
zookeeperconnect=${zookeeperconnect%,}

docker exec "$1" bash -c "sed -i '/^zookeeper.connect=/d' $KAFKA_CFG && echo 'zookeeper.connect=$zookeeperconnect' >>$KAFKA_CFG"
log INFO_s "zookeeper.connect=$zookeeperconnect on $1"
