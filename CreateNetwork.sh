#!/bin/bash
. ./functions
#Set network segment IP and network name. Net name can be any word.
#Network IP must be from the one of follow private ranges. Regular expression is deal with it.
#10.0.0.0/8
#172.16.0.0/12
#192.168.0.0/16

######
if [ -f NetName ]; then
	log INFO "Network already existed, use $(cat NetName).";
	exit 1;
fi;
######

log WARN "Network IP must be from the one of follow ranges:\n10.0.0.0/8\n172.16.0.0/12\n192.168.0.0/16";
while true; do
	read -p "Input network IP = " IP;
	[[ $IP =~ ^0?10\. && $IP =~ /([8-9]|[1-2][0-9]|[3][0-2])$  ||
	    $IP =~ ^172\.(1[6-9]|2[0-9]|3[0-2])\. && $IP =~ /(1[2-9]|2[0-9]|3[0-2])$ ||
	    $IP =~ ^192\.168\. && $IP =~ /(1[6-9]|2[0-9]|3[0-2])$ ]];

	if [ $? -eq 0 ]; then
		while true; do
			read -p "Input network name = " NetName;
			docker network create --subnet=$IP $NetName 1>/dev/null;
			if [ $? -eq 0 ]; then
				echo $NetName > NetName;
				log INFO "Network $NetName is created. IP range is $IP";
				exit 0;
			else
			    #If trouble with network creation here, 99% it means wrong network name.
			    #So program will be looped again.
				log ERROR "Something wrong with network creation. Re-do it again while success."
				break;
			fi; 
		done;
	else
		log WARN "Network IP must be from the one of follow ranges:\n10.0.0.0/8\n172.16.0.0/12\n192.168.0.0/16";
	fi;
done;
