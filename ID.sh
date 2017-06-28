#!/bin/bash
# $1 - Container type (zookeeper/kafka)
# $2 - operation (create/delete)

if [[ "$1" != kafka && "$1" != zookeeper ]]; then
	log ERROR "Usage: $0 baseimage-(zookeeper/kafka) (create/delete)";
	exit 1;
fi;
if [[ "$2" != create && "$2" != delete ]]; then
	log ERROR "Usage: $0 baseimage-(zookeeper/kafka) (create/delete)";
	exit 1;
fi;

if [ "$2" = create ]; then
        if [ "$(cat $1_myid | wc -l)" -eq 0 ]; then
                echo 1 >> $1_myid;
        else
                echo $(($(cat $1_myid)+1)) > $1_myid;
        fi;
elif [ "$2" = delete ]; then
        if [ "$(cat $1_myid | wc -l)" -eq 0 ]; then
                echo 1 >> $1_myid;
        else
                echo $(($(cat $1_myid)-1)) > $1_myid;
        fi;
fi;
