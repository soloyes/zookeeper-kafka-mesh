#!/usr/bin/env bash
# End-to-end test: build the images, grow a mesh to 3 ZooKeeper + 2 Kafka,
# check the ensemble, the broker registrations and a produce/consume round trip,
# shrink it to 2 + 1, check again, then tear everything down with Clear.sh.
#
# Needs Linux bash, GNU-compatible tools and a docker CLI talking to a daemon.
# On macOS run it through tests/run-in-docker.sh.
#
# Environment:
#   E2E_SUBNET      subnet for the test network (default 10.231.0.0/24)
#   E2E_NETWORK     network name (default zkmesh-e2e)
#   E2E_SKIP_BUILD  1 = use already built images
#   E2E_KEEP        1 = leave the mesh running at the end
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

SUBNET=${E2E_SUBNET:-10.231.0.0/24}
NETWORK=${E2E_NETWORK:-zkmesh-e2e}
TOPIC=e2e-topic

step() { echo; echo "=== $*"; }
fail() {
    echo "E2E FAILED: $*" >&2
    local k
    for k in $(nodes kafka); do
        echo "--- kafka $k: last lines of server.log" >&2
        docker exec "$k" tail -40 /home/kafka/logs/server.log >&2 || true
    done
    exit 1
}

cleanup() {
    if [ "${E2E_KEEP:-0}" != 1 ] && [ -f NetName ]; then
        step "Clear.sh"
        ./Clear.sh
    fi
}
trap cleanup EXIT

[ -f NetName ] && fail "a mesh already exists here (NetName), run ./Clear.sh first"

nodes() { docker ps -q --filter "network=$NETWORK" --filter "ancestor=baseimage-$1"; }

# Retry "$@" until it succeeds, up to $TRIES seconds.
retry() {
    local n=0
    until "$@"; do
        n=$((n + 1))
        [ "$n" -ge "${TRIES:-90}" ] && return 1
        sleep 1
    done
}

# Every ZooKeeper node answers "srvr"; exactly one leader, the rest followers.
zk_modes() {
    local id
    for id in $(nodes zookeeper); do
        docker exec "$id" bash -c "echo srvr | nc -w 3 localhost 2181" | sed -n 's/^Mode: //p'
    done | sort | uniq -c | awk '{printf "%s=%s ", $2, $1}'
}
zk_ok() {
    local want=$1 modes
    modes=$(zk_modes)
    if [ "$want" -eq 1 ]; then
        [ "$modes" = "standalone=1 " ]
    else
        [ "$modes" = "follower=$((want - 1)) leader=1 " ]
    fi
}

zk_connect() {
    local ip id list=""
    for id in $(nodes zookeeper); do
        ip=$(docker inspect --format "{{ (index .NetworkSettings.Networks \"$NETWORK\").IPAddress }}" "$id")
        list="$list$ip:2181,"
    done
    echo "${list%,}"
}

broker_ids() {
    local k
    k=$(nodes kafka | head -1)
    docker exec "$k" /home/kafka/bin/zookeeper-shell.sh "$(zk_connect)" ls /brokers/ids 2>/dev/null | tail -1
}
brokers_ok() { [ "$(broker_ids)" = "$1" ]; }

kafka() {
    local k=$1; shift
    docker exec -i "$k" "$@"
}

consume_all() {
    kafka "$1" /home/kafka/bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 \
        --topic "$TOPIC" --partition 0 --offset earliest --max-messages "$2" --timeout-ms 60000 \
        --consumer-property enable.auto.commit=false 2>/dev/null
}

verify() {
    local zk=$1 ids=$2
    step "Verify ZooKeeper ensemble ($zk nodes)"
    TRIES=120 retry zk_ok "$zk" || fail "ensemble not healthy: $(zk_modes)"
    for id in $(nodes zookeeper); do
        echo "  $id: $(docker exec "$id" bash -c 'echo srvr | nc -w 3 localhost 2181' | grep -E '^(Zookeeper version|Mode)' | tr '\n' ' ')"
    done
    echo "  modes: $(zk_modes)"
    echo "  zoo.cfg servers on $(nodes zookeeper | head -1):"
    docker exec "$(nodes zookeeper | head -1)" grep '^server\.' /etc/zookeeper/conf/zoo.cfg | sed 's/^/    /'

    step "Verify Kafka brokers registered in ZooKeeper (want $ids)"
    TRIES=120 retry brokers_ok "$ids" || fail "brokers in /brokers/ids: '$(broker_ids)', want '$ids'"
    echo "  /brokers/ids = $(broker_ids)"
    for k in $(nodes kafka); do
        echo "  $k: $(docker exec "$k" grep -E '^(broker.id|zookeeper.connect)=' /home/kafka/config/server.properties | tr '\n' ' ')"
    done
}

if [ "${E2E_SKIP_BUILD:-0}" != 1 ]; then
    step "Build images"
    docker build -t baseimage-zookeeper -f DockerfileZ . || fail "build baseimage-zookeeper"
    docker build -t baseimage-kafka -f DockerfileK . || fail "build baseimage-kafka"
fi

step "Scale up: 3 ZooKeeper + 2 Kafka"
./init.sh --subnet "$SUBNET" --network "$NETWORK" --zookeepers 3 --kafkas 2 || fail "init.sh scale up"
[ "$(nodes zookeeper | wc -l)" -eq 3 ] || fail "want 3 zookeeper containers"
[ "$(nodes kafka | wc -l)" -eq 2 ] || fail "want 2 kafka containers"
verify 3 "[1, 2]"

step "Produce and consume through the cluster"
K_OLD=$(nodes kafka | tail -1)   # broker 1, survives the scale-down
K_NEW=$(nodes kafka | head -1)   # broker 2
kafka "$K_OLD" /home/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --create \
    --topic "$TOPIC" --partitions 1 --replication-factor 2 || fail "create topic"
kafka "$K_OLD" /home/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --describe --topic "$TOPIC"
echo "hello from broker 1" | kafka "$K_OLD" /home/kafka/bin/kafka-console-producer.sh \
    --bootstrap-server localhost:9092 --topic "$TOPIC" --producer-property acks=all || fail "produce"
got=$(consume_all "$K_NEW" 1)
echo "  consumed on broker 2: '$got'"
[ "$got" = "hello from broker 1" ] || fail "message not consumed on broker 2"

step "Scale down: remove one ZooKeeper and one Kafka node"
./init.sh --zookeepers 2 --kafkas 1 || fail "init.sh scale down"
[ "$(nodes zookeeper | wc -l)" -eq 2 ] || fail "want 2 zookeeper containers"
[ "$(nodes kafka | wc -l)" -eq 1 ] || fail "want 1 kafka container"
verify 2 "[1]"

step "Data survived on the remaining broker"
echo "hello after scale-down" | kafka "$K_OLD" /home/kafka/bin/kafka-console-producer.sh \
    --bootstrap-server localhost:9092 --topic "$TOPIC" || fail "produce after scale-down"
got=$(consume_all "$K_OLD" 2 | tr '\n' '|')
echo "  consumed on broker 1: '$got'"
[ "$got" = "hello from broker 1|hello after scale-down|" ] || fail "messages after scale-down"

step "Scale up again: back to 3 ZooKeeper + 2 Kafka"
./init.sh --zookeepers 3 --kafkas 2 || fail "init.sh scale up again"
verify 3 "[1, 2]"

echo
echo "E2E PASSED"
