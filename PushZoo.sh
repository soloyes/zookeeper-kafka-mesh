#!/bin/bash
#Push zoo IDs to zoo containers
# $1 - Container ID
# $2 - Container type (zookeeper/kafka)
docker exec $1 /bin/bash -c "cp -f /etc/zookeeper/conf/zoo.cfg /etc/zookeeper/conf/zoo.cfg.backup";
docker exec $1 /bin/bash -c "cp -f /etc/zookeeper/conf/zoo.cfg.infobip /etc/zookeeper/conf/zoo.cfg";
#Add all servers to zoo.cfg
for j in $(cat $2IP | awk '{print $2}'); do
	docker exec $1 /bin/bash -c "echo "server.$(docker exec $j /bin/bash -c "cat /etc/zookeeper/conf/myid")=$(docker network inspect --format "{{ index .Containers \"$(docker inspect --format "{{ .Id }}" $j)\" }}" $(cat NetName) | awk '{print $4}' | sed 's/\/.*//'):2888:3888" >> /etc/zookeeper/conf/zoo.cfg";
done;
echo "Restart $2 process on container $(docker exec $1 /bin/bash -c "cat /etc/hosts | grep $1" | awk '{print $1}')";
docker exec $1 /usr/share/zookeeper/bin/zkServer.sh restart 1>/dev/null 2>/dev/null;
