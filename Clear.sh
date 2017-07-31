#!/bin/bash
#Delete all containers and network
. ./functions

log STARS;
log WARN "Clear all configuration with Clear.sh";

if [ -e NetName ]; then
	j=0;
	for i in $(docker ps -q); do 
		docker inspect $i | grep "$(cat NetName)" 1>/dev/null 2>/dev/null;
		if [ $? -eq 0 ]; then
			NetNameContainers[$j]=$i;
		fi;
		((j++));
	done;
	for i in ${NetNameContainers[@]}; do 
		docker stop $i 1>/dev/null 2>/dev/null;
	done;
	docker network rm $(cat NetName) 1>/dev/null;
	[ $? -eq 0 ]; rm NetName; [ $? -eq 0 ]; rm *IP; rm *myid;
else
	log ERROR "There is no network, please create it using init.sh";
fi;

log STARS;
log INFO "Exit Clear.sh";
