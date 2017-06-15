#!/bin/bash
#Check, whether we have any ran zookeeper or kafka containers.
# $1 - Container type (zookeeper/kafka)
# $2 - create/delete
if [[ "$1" != kafka && "$1" != zookeeper ]]; then
	echo "Usage: $0 imagename(zookeeper/kafka) operation(create/delete)"
	exit 1;
fi;
Containers=$(docker ps | grep baseimage-$1 | wc -l);
if [[ $Containers -eq 0 && "$1" == kafka ]]; then
	echo "There are no any $1, create?";
	select yesno in "Yes" "No"
	do
		[[ $yesno = No ]] && exit 1 || exit 0; #If 1 - init.sh -> Bye, If 2 - init.sh -> CreateContainer.sh
	done;
elif [[ $Containers -eq 0 && "$1" = zookeeper ]];then
	echo "There are no any $1. Creating..." #init.sh -> CreateContainer.sh
else
	docker ps | grep baseimage-$1;
	echo -e "\nThere are exist $1 containers above, $([ "$2" = create ] && echo 'create more?' || echo 'delete?')";

	#Check all IP's and re-create IP file. When we will add new nodes, we will add strings to file. When check again from init.sh, we analyse all
	#nodes from the begin. It is better to prevent any addition controls because there could be non-sequence IP's
	rm $1IP;
	for i in $(docker ps | grep $1 | awk '{print $1}'); do
		#Get big ID from short ID. Then get IP from big ID and NetName
		echo $(docker network inspect --format "{{ index .Containers \"$(docker inspect --format "{{ .Id }}" $i)\" }}" $(cat NetName) | awk '{print $4}' | sed 's/\/.*//') $i >> $1IP;
	done;
	select yesno in "Yes" "No"
	do
		[[ $yesno = No ]] && exit 1 || exit 0; #If 1 - init.sh -> Bye, If 2 - init.sh -> CreateContainer.sh
		break;
	done;
fi;
unset Containers;
