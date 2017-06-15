#!/bin/bash
password="root";
for i in $(docker ps | awk '{print $1 " "$2}' | grep -e zookeeper -e kafka | awk '{print $1}'); do
	echo -e "$password\n$password" | docker exec -i $i passwd;
done;
