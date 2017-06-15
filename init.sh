#!/bin/bash
. ./functions
#InfoBip interview test procedure. Prepared by Solovev Vitaly.
######
clear;
sleep 1;
log INFO "Welcome to infoBip interview test procedure.";
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
log INFO "Now we will start to configure internal network.";
./CreateNetwork.sh;
echo -e "\n* * *\n";
######

#Check and create zookeeper node(s)
./CheckContainer.sh zookeeper create;
if [ $? -eq 0 ]; then
	./CreateContainer.sh zookeeper;
fi;
#Exit when add failure
if [ $? -eq 1 ]; then
	exit 1;
fi;
echo -e "\n* * *\n";
#Check and create kafka node(s)
./CheckContainer.sh kafka create;
if [ $? -eq 0 ]; then
        ./CreateContainer.sh kafka;
fi;
#Exit when add failure
if [ $? -eq 1 ]; then
        exit 1;
fi;
echo -e "\n* * *\n";
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
exit 0;
