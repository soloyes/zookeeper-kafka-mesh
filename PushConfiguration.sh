#!/usr/bin/env bash
# Join a freshly started container to the mesh without stopping the service:
#   1. give the new node its id (ZooKeeper myid / Kafka broker.id), write its
#      configuration and start it; give up if it does not come up;
#   2. push the new configuration to every other node of the same type and
#      restart them one by one, checking each one before the next;
#   3. after a new ZooKeeper node, do the same for every Kafka broker
#      (zookeeper.connect changed);
#   4. if any restart fails, put the .backup configuration back on every node
#      changed so far and restart it.
# $1 - Container ID
# $2 - Container type (zookeeper/kafka)
# $3 - Container IP
# $4 - MyID
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
. ./functions

if [[ "$2" != kafka && "$2" != zookeeper ]] || [[ -z "$1" || -z "$3" || -z "$4" ]]; then
    log ERROR "Usage: $0 ContainerID (zookeeper/kafka) ContainerIP MyID"
    exit 1
fi

ChangedContainers=()

rollback() {
    local j
    for j in "$@"; do
        if [ "$(docker inspect --format '{{.Config.Image}}' "$j" 2>/dev/null)" = baseimage-zookeeper ]; then
            RestoreZoo "$j"
        else
            RestoreKafka "$j"
        fi
    done
}

execute() {
    local i
    if ! push_and_check "$1" "$2"; then
        log ERROR "New $2 node $3 did not start"
        exit 1
    fi
    log INFO "New $2 node $3 started. $([ "$(grep -c . "$2IP")" -ne 1 ] && echo "Restarting other nodes:")"

    for i in $(awk -v ip="$3" '$1 != ip {print $2}' "$2IP"); do
        # Remember changed nodes to roll them back if a later one fails.
        ChangedContainers+=("$i")
        if ! push_and_check "$i" "$2"; then
            log ERROR "$2 on $(node_ip "$i") did not come back. Rolling back:"
            rollback "${ChangedContainers[@]}"
            exit 1
        fi
        log INFO "$2 server $(node_ip "$i") restarted successfully"
    done

    # Every ZooKeeper node now has the new server list: the ensemble must elect a leader
    # and serve requests before anything else happens.
    if [ "$2" = zookeeper ]; then
        if ! wait_zk_ensemble; then
            log ERROR "The zookeeper ensemble does not serve requests with the new node. Rolling back:"
            rollback "${ChangedContainers[@]}"
            exit 1
        fi
        log INFO "zookeeper ensemble is serving: $(zk_modes)"
    fi

    # After a ZooKeeper node was added every Kafka broker needs the new zookeeper.connect.
    if [ "$2" = zookeeper ] && [ -s kafkaIP ]; then
        log INFO "Restarting kafka brokers with the new zookeeper.connect:"
        for i in $(awk '{print $2}' kafkaIP); do
            ChangedContainers+=("$i")
            if ! push_and_check "$i" kafka; then
                log ERROR "kafka on $(node_ip "$i") did not come back. Rolling back:"
                rollback "${ChangedContainers[@]}"
                exit 1
            fi
            log INFO "kafka server $(node_ip "$i") restarted successfully"
        done
    fi
    exit 0
}

if [ "$2" = zookeeper ]; then
    docker exec "$1" bash -c "echo $4 >$ZK_CONF/myid && { [ -f $ZK_CONF/zoo.cfg.template ] || cp -f $ZK_CONF/zoo.cfg $ZK_CONF/zoo.cfg.template; }"
else
    docker exec "$1" sed -i "s/^broker.id=0\$/broker.id=$4/" "$KAFKA_CFG"
fi
execute "$1" "$2" "$3"
