#!/usr/bin/env bash
# Remove the newest zookeeper/kafka node from the mesh and roll the new
# configuration over the remaining nodes one by one.
# Exit code: 0 = done; 1 = the last ZooKeeper was removed (whole mesh cleared)
#            or a remaining node did not come back; 2 = cancelled.
# $1 - Container type (zookeeper/kafka)
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
. ./functions

if [[ "$1" != kafka && "$1" != zookeeper ]]; then
    log ERROR "Usage: $0 (zookeeper/kafka)"
    exit 1
fi
if [ ! -f NetName ]; then
    log ERROR "There is no network, please create it using init.sh"
    exit 1
fi

refresh_state "$1"
# Newest first: ids come from a counter, so the newest node holds the highest id.
victim=$(list_nodes "$1" | head -1)
if [ -z "$victim" ]; then
    log WARN "There are no $1 nodes to delete"
    exit 0
fi
victim_ip=$(node_ip "$victim")

if [ "$1" = zookeeper ] && [ "$(grep -c . zookeeperIP)" -eq 1 ]; then
    log WARN "This is the last zookeeper. Deleting it deletes the whole mesh. Continue?"
    if is_noninteractive; then
        log ERROR "Refusing to delete the last zookeeper in non-interactive mode, use Clear.sh"
        exit 2
    fi
    (selectYN) || exit 2
    ./Clear.sh
    exit 1
fi

log INFO "Delete $1 container $victim_ip ($victim)"
if [ "$1" = kafka ]; then
    # Every partition must have an in-sync copy outside the victim before it goes,
    # then a controlled shutdown hands its partition leadership over.
    wait_kafka_in_sync "$victim" || log WARN "Partitions are not fully in sync, removing $victim_ip anyway"
    stop_kafka "$victim" || log WARN "Kafka on $victim_ip did not shut down cleanly"
fi
docker stop "$victim" >/dev/null 2>&1
./ID.sh "$1" delete
remove_ip_line "$1IP" "$victim_ip"

failed=0
for i in $(awk '{print $2}' "$1IP"); do
    if push_and_check "$i" "$1"; then
        log INFO "$1 server $(node_ip "$i") restarted successfully"
    else
        log ERROR "$1 on $(node_ip "$i") did not come back, check it by hand"
        failed=1
    fi
done

# The ZooKeeper list changed: every Kafka broker needs the new zookeeper.connect.
if [ "$1" = zookeeper ] && [ -s kafkaIP ]; then
    for i in $(awk '{print $2}' kafkaIP); do
        if push_and_check "$i" kafka; then
            log INFO "kafka server $(node_ip "$i") restarted successfully"
        else
            log ERROR "kafka on $(node_ip "$i") did not come back, check it by hand"
            failed=1
        fi
    done
fi
exit "$failed"
