#!/usr/bin/env bash
# (Re)start the Kafka broker on one container and wait until it is really up.
# $1 - Container ID
# $2 - Container type (kafka)
#
# Stop:  kafka-server-stop.sh, then wait for "shut down completed (kafka.server.KafkaServer)".
# Start: kafka-server-start.sh -daemon, then wait for "started (kafka.server.KafkaServer)",
#        which Kafka logs only after the broker has registered itself in ZooKeeper.
# Only log lines written after the command are taken into account.
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
. ./functions

STOP_TIMEOUT=${ZKM_KAFKA_STOP_TIMEOUT:-90}
START_TIMEOUT=${ZKM_KAFKA_START_TIMEOUT:-120}

if [[ -z "$1" || "$2" != kafka ]]; then
    log ERROR "Usage: $0 ContainerID kafka"
    exit 1
fi

log INFO "Restart kafka process on container $(node_ip "$1")"

if kafka_running "$1"; then
    if ! ZKM_KAFKA_STOP_TIMEOUT=$STOP_TIMEOUT stop_kafka "$1"; then
        log ERROR "Kafka on $(node_ip "$1") did not shut down within ${STOP_TIMEOUT}s"
        exit 1
    fi
    # The JVM may still be exiting after the last log line.
    for _ in $(seq 1 30); do
        kafka_running "$1" || break
        sleep 1
    done
fi

from=$(kafka_log_lines "$1")
docker exec "$1" "$KAFKA_HOME/bin/kafka-server-start.sh" -daemon "$KAFKA_CFG"
if ! wait_kafka_log "$1" 'started (kafka.server.KafkaServer)' "$from" "$START_TIMEOUT"; then
    log ERROR "Kafka on $(node_ip "$1") did not start within ${START_TIMEOUT}s"
    exit 1
fi
exit 0
