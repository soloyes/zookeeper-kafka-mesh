#!/bin/bash
# $1 - Container type (zookeeper/kafka)
if [[ "$1" != kafka && "$1" != zookeeper ]]; then
        echo "Usage: $0 imagename(zookeeper/kafka)";
        exit 1;
fi;
if [ "$1" = zookeeper ]; then
	if [ "$(cat $1IP | wc -l)" = 1 ]; then		
		echo "Warning, if delete last zookeeper, then delete all system automatically. Continue?";
		select yesno in "Yes" "No"
        	do
                	if [ $yesno = No ]; then 
			exit 0; 
			else
			./Clear.sh;
			exit 1;
			fi;
        	break;
		done;
	else
		#Delete, push zookeeper
		containerTodelete=($(cat $1IP | head -1 ));
		echo "Delete $1 container ${containerTodelete[0]}";
		docker stop ${containerTodelete[1]} 1>/dev/null 2>/dev/null;
		./ID.sh $1 delete;
		sed -i "/${containerTodelete[0]}/d" $1IP;
		for i in $(grep -v "${containerTodelete[1]}" $1IP | awk '{print $2}'); do
			./PushZoo.sh $i $1;		
		done;
		unset containerTodelete;		
		#Push kafka
		if [ "$(cat kafkaIP | wc -l)" = 0 ]; then
			exit 0;
		else
		for i in $(cat kafkaIP | awk '{print $2}'); do
			docker exec $i /bin/bash -c "cp -f /home/kafka/config/server.properties /home/kafka/config/server.properties.backup";
        		./UpdateKafkaCfg.sh $i kafka;
        		./RestartKafkaProcess.sh $i kafka;
		done;
		exit 0;
		fi;	
	fi;
elif [ "$1" = kafka ];then
	containerTodelete=($(cat $1IP | head -1 ));
	echo "Delete $1 container ${containerTodelete[0]}";
	docker stop ${containerTodelete[1]} 1>/dev/null 2>/dev/null;
	./ID.sh $1 delete;
	sed -i "/${containerTodelete[0]}/d" $1IP;
	for i in $(cat $1IP | awk '{print $2}'); do
		docker exec $i /bin/bash -c "cp -f /etc/hosts /etc/hosts.backup";
		docker exec $i /bin/bash -c "cp -f /etc/hosts /etc/hosts.infobip";
		docker exec $i /bin/bash -c "cp -f /home/kafka/config/server.properties /home/kafka/config/server.properties.backup";
		docker exec $i /bin/bash -c "sed -i '/${containerTodelete[0]}/d' /etc/hosts.infobip";
		docker exec $i /bin/bash -c "cp -f /etc/hosts.infobip /etc/hosts";
		./UpdateKafkaCfg.sh $i kafka;
		./RestartKafkaProcess.sh $i kafka;
	done;
	unset containerTodelete;
	exit 0;
fi;
