#!/bin/bash

if [ ! "$1" -o ! "$2" ];then
    echo "<Usage> ./collect.sh <vm-list> <result-file>"
    exit 1
fi

#input file
IN=$1

PEGASUS_HOME="/home/pegasus-user"
PEGASUS_USR="pegasus-user"
PEGASUS_PASS="pegasus"
LOG=$2

SSH="sshpass -p $PEGASUS_PASS ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
CMD="cat $LOG 2> /dev/null" 

#skip empty and comment lines
while read line;do 
	if  [ "$line" -a "${line:0:1}" != "#" ];then
		nodes=("${nodes[@]}" "$line")
	fi
done < $IN

for (( i=0;i<${#nodes[@]};i ++ ));do
	NAME=$(echo ${nodes[$i]} | awk '{print $1}')
	IP=$(echo ${nodes[$i]} | awk '{print $2}')
	echo $NAME $IP
	if [ "$IP" ];then
		$SSH $PEGASUS_USR@$IP $CMD 2> /dev/null || echo "Failed to connect."
	else
		echo -e "Not Available"
	fi
done; 
