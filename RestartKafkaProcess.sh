#!/bin/bash
#Restart kafka containers
# $1 - Container ID
# $2 - Container type (zookeeper/kafka)
echo "Restart $2 process on container $(docker exec $1 /bin/bash -c "cat /etc/hosts | grep $1" | awk '{print $1}')";
kafkaprocess=($(docker exec $1 /bin/bash -c "ps ax | grep -i 'kafka\.Kafka' | grep java | grep -v grep"));
if [ "${kafkaprocess[0]}" = "" ]; then
	docker exec $1 /bin/bash -c "/home/kafka/bin/kafka-server-start.sh -daemon /home/kafka/config/server.properties";
else
	docker exec $1 /bin/bash -c "/home/kafka/bin/kafka-server-stop.sh";
	test=$(docker exec $1 /bin/bash -c "tail -30 /home/kafka/logs/server.log | grep 'shut down completed (kafka.server.KafkaServer)'");
	while [ "$test" = "" ]; do
		sleep 1;
		test=$(docker exec $1 /bin/bash -c "tail -30 /home/kafka/logs/server.log | grep 'shut down completed (kafka.server.KafkaServer)'");
	done;
	unset test;
	docker exec $1 /bin/bash -c "/home/kafka/bin/kafka-server-start.sh -daemon /home/kafka/config/server.properties";
fi;
unset kafkaprocess;
