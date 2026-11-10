#!/usr/bin/env bash
# zookeeper-kafka-mesh: grow or shrink a ZooKeeper ensemble and a Kafka cluster
# in docker, one node at a time, without stopping the service.
#
# Interactive menu:   ./init.sh
# Non-interactive:    ./init.sh --subnet 10.10.10.0/24 --network zkmesh --zookeepers 3 --kafkas 2
#                     (or the same through ZKM_SUBNET, ZKM_NETWORK, ZKM_ZOOKEEPERS, ZKM_KAFKAS)
# In non-interactive mode the mesh is scaled up or down to the requested number of
# nodes; run it again with other numbers to add or remove nodes.
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
. ./functions

usage() {
    cat <<USAGE
Usage: $0 [--subnet CIDR] [--network NAME] [--zookeepers N] [--kafkas N]

Without options an interactive menu asks for everything.
With --zookeepers and/or --kafkas nothing is asked: the mesh is scaled to N nodes.
  --subnet CIDR     subnet for a new docker network (private range), env ZKM_SUBNET
  --network NAME    name of the new docker network (default zkmesh), env ZKM_NETWORK
  --zookeepers N    wanted number of ZooKeeper nodes (>= 1), env ZKM_ZOOKEEPERS
  --kafkas N        wanted number of Kafka brokers (>= 0), env ZKM_KAFKAS
USAGE
}

while [ $# -gt 0 ]; do
    case "$1" in
        --subnet)     ZKM_SUBNET=$2; shift 2 ;;
        --network)    ZKM_NETWORK=$2; shift 2 ;;
        --zookeepers) ZKM_ZOOKEEPERS=$2; shift 2 ;;
        --kafkas)     ZKM_KAFKAS=$2; shift 2 ;;
        -h|--help)    usage; exit 0 ;;
        *)            usage; exit 1 ;;
    esac
done

if [ -n "${ZKM_ZOOKEEPERS:-}" ] || [ -n "${ZKM_KAFKAS:-}" ]; then
    export ZKM_NONINTERACTIVE=1
fi
export ZKM_SUBNET ZKM_NETWORK

######
is_noninteractive || clear
log INFO "Welcome to zookeeper-kafka-mesh!"
log INFO "Scale a ZooKeeper ensemble and a Kafka cluster in docker without downtime."
log
######

######
log INFO "Check the docker daemon. If it has to be started, you may be asked for your password."
./CheckProcess.sh || exit 1
######

######
log INFO "Configure internal network."
./CreateNetwork.sh
rc=$?
if [ "$rc" -eq 2 ] || [ ! -f NetName ]; then
    exit 1
fi
log STARS
######

######
# Non-interactive: scale every type to the wanted number of nodes.
if is_noninteractive; then
    for type in zookeeper kafka; do
        if [ "$type" = zookeeper ]; then
            want=${ZKM_ZOOKEEPERS:-}
        else
            want=${ZKM_KAFKAS:-}
        fi
        ./CheckContainer.sh "$type" create
        have=$(grep -c . "${type}IP")
        if [ -z "$want" ]; then
            want=$have
            [ "$type" = zookeeper ] && [ "$want" -lt 1 ] && want=1
        fi
        if ! [[ "$want" =~ ^[0-9]+$ ]] || { [ "$type" = zookeeper ] && [ "$want" -lt 1 ]; }; then
            log ERROR "Wanted number of $type nodes '$want' is not valid (zookeeper >= 1, kafka >= 0)"
            exit 1
        fi
        log INFO "$type: $have running, $want wanted"
        while [ "$have" -lt "$want" ]; do
            ./CreateContainer.sh "$type" || exit 1
            have=$((have + 1))
        done
        while [ "$have" -gt "$want" ]; do
            ./DeleteContainer.sh "$type" || exit 1
            have=$((have - 1))
        done
        log STARS
    done
    log INFO "Exit init.sh"
    exit 0
fi
######

######
# Interactive: check and create zookeeper/kafka node(s).
for i in zookeeper kafka; do
    if ./CheckContainer.sh "$i" create; then
        while true; do
            ./CreateContainer.sh "$i"
            rc=$?
            if [ "$rc" -eq 1 ]; then
                break
            elif [ "$rc" -eq 2 ]; then
                # Adding a node failed (already rolled back): stop here.
                exit 1
            fi
        done
    fi
    log STARS
done
######

######
# Delete menu
if ./CheckContainer.sh zookeeper delete; then
    ./DeleteContainer.sh zookeeper
    # 1 after the last zookeeper was deleted: the whole mesh is gone.
    if [ $? -eq 1 ] && [ ! -f NetName ]; then
        exit 1
    fi
fi
log STARS
if ./CheckContainer.sh kafka delete; then
    ./DeleteContainer.sh kafka
fi

log STARS
log INFO "Exit init.sh"
log STARS
exit 0
