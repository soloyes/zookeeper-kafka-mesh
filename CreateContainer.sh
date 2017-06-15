#!/bin/bash
#Create zookeeper/kafka container
# $1 - Container type (zookeeper/kafka) 
if [ ! -f NetName ]; then 
	echo "There is no network, please create it using init.sh";
	exit 1;
fi;
if [[ "$1" != kafka && "$1" != zookeeper ]]; then
	echo "Usage: $0 imagename(zookeeper/kafka) operation(create/delete)"; 
	exit 1;
fi;
while true; do
	ID=$(docker run --net $(cat NetName) -itd baseimage-$1 /sbin/my_init -- bash -l);
	IP=$(docker network inspect --format "{{ index .Containers \"$ID\" }}" $(cat NetName) | awk '{print $4}' | sed 's/\/.*//');	
	[ ! -f $1IP ] && touch $1IP;
	[ ! -f $1_myip ] && touch $1_myid;
	./ID.sh $1 create;
	echo "$IP ${ID:0:12}" >> $1IP;
	echo "New $1 container $IP";
	./PushConfiguration.sh ${ID:0:12} $1 $IP $(cat $1_myid);
	#If nothing problem, we can add more.
	if [ $? -eq 0 ]; then	
		echo "Create one more?";
		select yesno in "Yes" "No"
		do
			if [ $yesno = No ]; then
				echo -e "$1 container(s) here:\n"
				docker ps | grep $1;	
				exit 0;
			else
				break;
			fi;
		done;
	else
		echo "Can not start service $1 on new server $IP";
		#Delete container in case of push failure
		docker stop $ID 1>/dev/null 2>/dev/null;
		echo "Container $IP stoped";
		./ID.sh $1 delete;
		sed -i "/$IP/d" $1IP;
		exit 1;
	fi;
done;
