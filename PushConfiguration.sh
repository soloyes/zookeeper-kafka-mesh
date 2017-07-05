#!/bin/bash
. ./functions
#Push IPs and IDs to containers
# $1 - Container ID
# $2 - Container type (zookeeper/kafka)
# $3 - ContainerIP
# $4 - MyID

######
if [[ "$2" != kafka && "$2" != zookeeper ]]; then
	log ERROR "Usage: $0 ContainerID (zookeeper/kafka) ContainerIP MyID";
	exit 1;
fi;

if [[ "$1" == "" || "$3" == "" || "$3" == "" ]]; then
	log ERROR "Usage: $0 ContainerID (zookeeper/kafka) ContainerIP MyID";
	exit 1;
fi;
######

function RestoreZoo() {
	log INFO "Backup and Restart $2 process on container "$(echo $(docker exec $1 /bin/bash -c "cat /etc/hosts | grep $1") | awk '{print $1}');
	docker exec $1 /bin/bash -c "cp -f /etc/zookeeper/conf/zoo.cfg.backup /etc/zookeeper/conf/zoo.cfg";
    docker exec $1 /usr/share/zookeeper/bin/zkServer.sh restart 1>/dev/null 2>/dev/null;
}

function RestoreKafka() {
	log INFO "Backup and Restart $2 process on container "$(echo $(docker exec $1 /bin/bash -c "cat /etc/hosts | grep $1") | awk '{print $1}');
    docker exec $1 /bin/bash -c "cp -f /etc/hosts.backup /etc/hosts";
	docker exec $1 /bin/bash -c "cp -f /home/kafka/config/server.properties.backup /home/kafka/config/server.properties";
	./RestartKafkaProcess.sh $1 $2;
}

function UpdateKafkaHosts() {
	#Add all broker IP Host to /etc/hosts to make full relation
	if [ "$1" =  "$(docker ps -lq)" ]; then
        while read line;
        do
            docker exec $1 /bin/bash -c "echo $line | grep -v $1 >> /etc/hosts";
        done <$2IP;
    else
	IP=$(docker network inspect --format "{{ index .Containers \"$(docker inspect --format "{{ .Id }}" $(docker ps -lq))\" }}" $(cat NetName) | awk '{print $4}' | sed 's/\/.*//');
    docker exec $1 /bin/bash -c "echo $IP $(docker ps -lq) >> /etc/hosts";
    fi;
	unset IP;
}
function PushKafka() {
	docker exec $1 /bin/bash -c "cp -f /etc/hosts /etc/hosts.backup";
	docker exec $1 /bin/bash -c "cp -f /home/kafka/config/server.properties /home/kafka/config/server.properties.backup";
	
	UpdateKafkaHosts $1 $2;	
	./UpdateKafkaCfg.sh $1 $2;
	./RestartKafkaProcess.sh $1 $2;
}
function PushKafkaZoo() {
	docker exec $1 /bin/bash -c "cp -f /home/kafka/config/server.properties /home/kafka/config/server.properties.backup";
	./UpdateKafkaCfg.sh $1 $2;
    ./RestartKafkaProcess.sh $1 $2;
}

function Check() {	
if [ "$2" = zookeeper ]; then
	###TEST Push failure
	#if [ "$(echo $(docker exec $1 /bin/bash -c "cat /etc/hosts | grep $1") | awk '{print $1}')" = "10.10.10.5" ]; then
	#docker exec $1 /bin/bash -c "rm /var/lib/zookeeper/zookeeper_server.pid";
	#fi;
	###
	[[ "$(echo $(docker exec $1 /bin/bash -c \
	" [[ -f /var/lib/zookeeper/zookeeper_server.pid ]] && echo 0 || echo 1"))" = 0 ]] && return 0 || return 1;
elif [ "$2" = kafka ]; then
	###TEST Push failure
	#if [ "$(echo $(docker exec $1 /bin/bash -c "cat /etc/hosts | grep $1") | awk '{print $1}')" = "10.10.10.3" ]; then
	#kafkaprocess[0]="";
	#else	
	kafkaprocess=($(docker exec $1 /bin/bash -c "ps ax | grep -i 'kafka\.Kafka' | grep java | grep -v grep"));	
	#fi;
	###
	[[ "${kafkaprocess[0]}" != "" ]] && return 0 || return 1;
	unset kafkaprocess;
fi;
}

function execute() {
	[[ "$2" = zookeeper ]] && ./PushZoo.sh $1 $2 || PushKafka $1 $2;
	Check $1 $2;
    [ $? -eq 1 ] && exit 1;
    echo "New node $2 server $3 restarted success. $([ "$(cat $2IP | wc -l)" -ne 1 ] && echo "Restarting other nodes:")";
    local i;
	for i in $(grep -v $3 $2IP | awk '{print $2}'); do
		#Remember changed servers to rollback in case of fail continue of configs pushing
        ChangedContainers+=("$i");
		#
        [[ "$2" = zookeeper ]] && ./PushZoo.sh $i $2 || PushKafka $i $2;
		Check $i $2;
        if [ $? -eq 1 ]; then
            echo "Some problems with process start appears. Backup containers:"
            local j;
			for j in "${ChangedContainers[@]}"; do
                [[ "$2" = zookeeper ]] && RestoreZoo $j $2 || RestoreKafka $j $2;
            done;
			unset j;
			unset ChangedContainers;
            exit 1;
        fi;
        echo "$2 server $(docker network inspect --format "{{ index .Containers \"$(docker inspect --format "{{ .Id }}" $i)\" }}" $(cat NetName) | awk '{print $4}' | sed 's/\/.*//') restarted success";
	done;
	unset i;

	#After each Zookeeper was added, we need to refresh all kafka nodes.
	if [ "$2" = zookeeper ]; then
		unset ChangedContainers;
		Containers=$(docker ps | grep baseimage-kafka | wc -l);
		if [[ $Containers -ne 0 ]]; then
			local i;
            for i in $(cat kafkaIP | awk '{print $2}'); do
                #Remember changed servers to rollback in case of fail continue of configs pushing
			    ChangedContainers+=("$i");
                #
                PushKafkaZoo $i kafka;
                Check $i kafka;
                if [ $? -eq 1 ]; then
                    echo "Some problems with process start appears. Backup containers:";
				    local i;
				    for i in $(grep -v $3 $2IP | awk '{print $2}'); do
		                RestoreZoo $i $2;
				    done;
				    unset i;
				    local j;

                    for j in "${ChangedContainers[@]}"; do
                        docker exec $j /bin/bash -c "cp -f /etc/hosts.backup /etc/hosts";
                        RestoreKafka $j kafka;
                    done;
                    unset j;
                    unset ChangedContainers;
                    exit 1;
                fi;
                echo "kafka server $(docker network inspect --format "{{ index .Containers \"$(docker inspect --format "{{ .Id }}" $i)\" }}" $(cat NetName) | awk '{print $4}' | sed 's/\/.*//') restarted success";
            done;
            unset i;
		fi;
		unset Containers;	
	fi;
    exit 0
}
#Here we try to update configurations on new container, then start it.
#In case of well started we shall update configs everywhere one-by-one. Then restart one-by-one.
#If restart failure, rollback configurations.
if [ "$2" = zookeeper ]; then
	docker exec $1 /bin/bash -c "echo $4 > /etc/zookeeper/conf/myid";
	docker exec $1 /bin/bash -c "cp -f /etc/zookeeper/conf/zoo.cfg /etc/zookeeper/conf/zoo.cfg.infobip";
	execute $1 $2 $3;
fi;

if [ "$2" = kafka ]; then
	docker exec $1 /bin/bash -c "sed -i 's/broker.id=0/broker.id=$4/g' /home/kafka/config/server.properties";
	execute $1 $2 $3;
fi;