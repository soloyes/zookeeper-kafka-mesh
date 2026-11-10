#!/usr/bin/env bash
# Start one new zookeeper/kafka container and join it to the mesh.
# Exit code: 0 = done, create one more; 1 = done, stop; 2 = failed (rolled back).
# $1 - Container type (zookeeper/kafka)
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
. ./functions

if [ ! -f NetName ]; then
    log ERROR "There is no network, please create it using init.sh"
    exit 2
fi
if [[ "$1" != kafka && "$1" != zookeeper ]]; then
    log ERROR "Usage: $0 (zookeeper/kafka)"
    exit 2
fi

# --rm: a node that is stopped (deleted or rolled back) leaves nothing behind.
if ! ID=$(docker run --rm --net "$(net_name)" -itd "baseimage-$1" /sbin/my_init -- bash -l); then
    log ERROR "Could not start a baseimage-$1 container. Did you build the images?"
    exit 2
fi
ID=${ID:0:12}
IP=$(node_ip "$ID")

touch "$1IP" "$1_myid"
# Keep IDs and IPs in the state files.
./ID.sh "$1" create
echo "$IP $ID" >>"$1IP"
MYID=$(cat "$1_myid")

log INFO "New $1 container $IP ($ID), id $MYID"
log INFO_s "$1IP contains: $(tr '\n' ';' <"$1IP")"

# Configure the new node, start it, then roll the change over the other nodes.
if ./PushConfiguration.sh "$ID" "$1" "$IP" "$MYID"; then
    is_noninteractive && exit 0
    log INFO "Create one more?"
    selectYN
else
    log ERROR "Can not start service $1 on new server $IP"
    # Remove the container on push failure; the other nodes were rolled back.
    docker stop "$ID" >/dev/null 2>&1
    log INFO "Container $IP stopped"
    ./ID.sh "$1" delete
    remove_ip_line "$1IP" "$IP"
    exit 2
fi
