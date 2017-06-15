#!/bin/bash
# $1 - Container type (zookeeper/kafka)
# $2 - operation (create/delete)
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
