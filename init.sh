#!/bin/bash
. ./functions
######
#InfoBip interview test procedure. Prepared by Solovev Vitaly.
######

######
clear;
sleep 1;
log INFO "Welcome to infoBip interview test procedure!";
log INFO "Prepared by Solovev Vitaly.";
log;
######

######
log INFO "Start to check a docker daemon. In case of start it, u may need to input your root password.";
./CheckProcess.sh;
if [ $? -eq 1 ]; then
    exit 1;
fi
######

######
log INFO "Configure internal network.";
./CreateNetwork.sh;
log STARS;
######

######
#Check and create zookeeper/kafka node(s)
for i in zookeeper kafka; do
	./CheckContainer.sh $i create;
	if [ $? -eq 0 ]; then
		while true; do
		./CreateContainer.sh $i;
			if [ $? -eq 1 ]; then
				break;
			#Exit init.sh, when add failure
			elif [ $? -eq 2 ]; then
	        		exit 1;
	    		fi
		done;
	fi;
	log STARS;
done;
######

######
#Check and create kafka node(s)
#./CheckContainer.sh kafka create;
#if [ $? -eq 0 ]; then
#	while true; do
#	./CreateContainer.sh kafka;
#		if [ $? -eq 1 ]; then
#			break;
#		#Exit init.sh, when add failure
#		elif [ $? -eq 2 ]; then
#			exit 1;
#		fi
#	done;
#fi;
#log STARS;
######

#Delete menu
./CheckContainer.sh zookeeper delete;
if [ $? -eq 0 ]; then
        ./DeleteContainer.sh zookeeper;
fi;
#Exit when delete last zookeeper
if [ $? -eq 1 ]; then
        exit 1;
fi;
echo -e "\n* * *\n";
./CheckContainer.sh kafka delete;
if [ $? -eq 0 ]; then
        ./DeleteContainer.sh kafka;
fi;

log STARS;
log INFO "Exit init.sh";
log SRARS;
exit 0;
