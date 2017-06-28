#!/bin/bash
. ./functions
#Check, whether we have any ran zookeeper or kafka containers.
# $1 - Container type (zookeeper/kafka)
# $2 - create/delete

######
if [[ "$1" != kafka && "$1" != zookeeper ]]; then
	log ERROR "Usage: $0 baseimage-(zookeeper/kafka) (create/delete)"
	exit 1;
fi;

if [[ "$2" != create && "$2" != delete ]]; then
	log ERROR "Usage: $0 baseimage-(zookeeper/kafka) (create/delete)"
	exit 1;
fi;
######

Containers=$(docker ps | grep baseimage-$1 | wc -l);
if [[ $Containers -eq 0 && "$1" == kafka ]]; then
	log WARN "There are no any $1, create?";
    selectYN;

elif [[ $Containers -eq 0 && "$1" = zookeeper ]]; then
    #Must exist at least one zookeeper.
	log INFO "There are no any $1. Creating..." #Here go to init.sh -> CreateContainer.sh zookeeper
else
	docker ps | grep baseimage-$1;
	log WARN "There are exist $1 containers above, $([ "$2" = create ] && echo 'create more?' || echo 'delete?')";

	#Check all IP's and re-create IP file.
	#When we will add new nodes, we will add strings to file.
	#When check again from init.sh, we analyse all nodes from the begin.
	#It is better to prevent any addition controls because there could be IP's in non-sequence.
	rm $1IP;
	for i in $(docker ps | grep $1 | awk '{print $1}'); do
		#Get big ID from short ID. Then get IP from big ID and NetName
		echo $(docker network inspect --format "{{ index .Containers \"$(docker inspect --format "{{ .Id }}" $i)\" }}" $(cat NetName) | awk '{print $4}' | sed 's/\/.*//') $i >> $1IP;
	done;

    selectYN;
fi;
unset Containers;
