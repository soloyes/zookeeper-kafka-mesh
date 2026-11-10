#!/usr/bin/env bash
# Set the root password on every ZooKeeper and Kafka container of the mesh,
# so you can "ssh root@<ip>" into them. Password: $ZKM_ROOT_PASSWORD (default "root").
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
. ./functions

if [ ! -f NetName ]; then
    log ERROR "There is no network, please create it using init.sh"
    exit 1
fi

password=${ZKM_ROOT_PASSWORD:-root}
for type in zookeeper kafka; do
    for i in $(list_nodes "$type"); do
        if echo "root:$password" | docker exec -i "$i" chpasswd; then
            log INFO "Root password set on $type $(node_ip "$i")"
        else
            log ERROR "Could not set root password on $type $(node_ip "$i")"
        fi
    done
done
