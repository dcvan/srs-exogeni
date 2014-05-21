#!/bin/bash

IN="wf-list.txt"
SSH="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"

PEGASUS_HOME="/home/pegasus-user"
JOB_HOME="$PEGASUS_HOME/genomics/wf_exon_irods/pegasus-user/pegasus/exonalignwf/run0001/"
LOG="$PEGASUS_HOME/wf.log"
CMD="pegasus-statistics $JOB_HOME 2> /dev/null || su pegasus-user -c \"pegasus-status -l $JOB_HOME\""

while read line;do
	if [ "$line" -a "${line:0:1}" != "#" ];then
		nodes=("${nodes[@]}" "$line")
	fi
done < $IN

for ((i = 0; i < ${#nodes[@]}; i ++));do
	NAME=$(echo ${nodes[$i]} | awk '{print $1}')
	IP=$(echo ${nodes[$i]} | awk '{print $2}')
	echo $NAME $IP
	if [ "$IP" ];then 
		$SSH root@$IP $CMD 2>> /dev/null | grep "^Workflow wall time" | awk -F':' '{print $2}' || echo "Fail to connect"
	else
		echo "Not available"
	fi
done
