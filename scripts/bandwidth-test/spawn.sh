#!/bin/bash

#input file
IN="bt-list.txt"
SCRIPT="bandwidth-test.sh"
DATA="genomicdata2"
RESULT="result.txt"
SSH_CMD="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
SCP_CMD="scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"

while read line;do
    if [ "$line" -a "${line:0:1}" != "#" ];then
	nodes=("${nodes[@]}" "$line")
    fi
done < $IN

for ((i = 0;i < ${#nodes[@]};i ++));do
    NAME=$(echo ${nodes[$i]} | awk '{print $1}')
    IP=$(echo ${nodes[$i]} | awk '{print $2}') 
    if [ "$IP" ];then
	$SSH_CMD root@$IP "killall $SCRIPT;rm -rf /root/$SCRIPT /root/$DATA /home/pegasus-user/result.txt;sysctl -w vm.drop_caches=3"
	$SCP_CMD $SCRIPT root@$IP:~
	$SSH_CMD root@$IP "/root/$SCRIPT &" &
	echo "$NAME ready."	    
    else
	echo -e "$NAME not available."
    fi
done 
