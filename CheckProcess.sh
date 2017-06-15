#!/bin/bash
. ./functions
#Check the process run. Start if needed.
cat /var/run/docker.pid 1>/dev/null 2>/dev/null;
if [ $? -ne 1 ]; then 
	log WARN "Docker process is already has been ran with PID="$(cat /var/run/docker.pid);
else
	i=0;
	while [ $i -ne "3" ]; do
		((i++));
		log INFO "Docker process is trying to start "$i
		service docker start;
		if [ $? -eq 0 ]; then   
			log INFO "Docker process has been started with PID="$(cat /var/run/docker.pid);
			unset i;
			exit 0;
		fi;
		sleep 2;
	done;
	log ERROR "Docker process is unable to start";
	unset i;
	exit 1;
fi;
