#!/bin/bash
#Add all zookeepers to kafka
# $1 - Container ID
        while read line
        do
                zookeeperconnect="$zookeeperconnect$(echo $line | awk '{print $1}'):2181,";
        done <zookeeperIP;
        docker exec $1 /bin/bash -c "sed -i "/zookeeper.connect=/d" /home/kafka/config/server.properties; echo "zookeeper.connect=${zookeeperconnect::-1}" >> /home/kafka/config/server.properties";
        unset zookeeperconnect;
