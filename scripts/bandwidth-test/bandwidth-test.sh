#!/bin/bash

#set PATH
export PATH="$PATH:/home/pegasus-user/iRODS/clients/icommands/bin"

#basic config
SVR_IP="10.0.0.2"
BANDWIDTH="10" #Mb/s
SVR_USR="pegasus-user"
SVR_PASS="pegasus"
PEGASUS_HOME="/home/pegasus-user"
ROOT_HOME="/root"

#irods config
IRODS_CFG=".irods/.irodsEnv"
IRODS_PORT=1247
IRODS_RESC="demoResc"
IRODS_ZONE="tempZone"
IRODS_USR="rods"
IRODS_PASS="$SVR_PASS"

#experiment config
NUM_OF_ITERS=20
INT=1 #mins
INT_INCR=1 #mins
OUTPUT="$PEGASUS_HOME/result.txt"
GENOMIC_DATA="genomicdata2"
DEST="$ROOT_HOME/$GENOMIC_DATA"

#ping config
PING_CMD="ping -c10 -i0.5 -w10"

#iget config
NUM_OF_THREADS=6
IGET_CMD="iget -rfV -N$NUM_OF_THREADS"

#scp config
SSH_CONFIG="$ROOT_HOME/.ssh/config"
SCP_CMD="sshpass -p $SVR_PASS scp -vr"

#set root's password
echo $SVR_PASS | passwd --stdin

#install sshpass
yum -y install sshpass

#disable ssh strict host key checking
echo "disabling ssh strict host key checking ..."
cat > $SSH_CONFIG << EOF
Host *
        StrictHostKeyChecking no
EOF
chmod 600 $SSH_CONFIG

#check server liveness
echo "checking server liveness ..."
while true;do
    ping -c1 -w2 $SVR_IP > /dev/null 2> /dev/null && break
done

#init irods client
echo "initiating irods client ..."
if [ ! -d $ROOT_HOME/.irods ];then
	mkdir -m 755 $ROOT_HOME/.irods
fi

cat > $IRODS_CFG << EOF
irodsHost '$SVR_IP'
irodsPort $IRODS_PORT
irodsDefResource '$IRODS_RESC'
irodsHome '/$IRODS_ZONE/home/$IRODS_USR'
irodsCwd '/$IRODS_ZONE/home/$IRODS_USR'
irodsUserName '$IRODS_USR'
irodsZone '$IRODS_ZONE'
EOF

chmod 600 $IRODS_CFG
while true;do
	iinit $IRODS_PASS && break
done

#create output file
touch $OUTPUT
chown -R $SVR_USR:$SVR_USR $OUTPUT

#start benchmark
echo "start benchmark.see results at $OUTPUT."
for ((i = 0; i < $NUM_OF_ITERS; i ++));do
	#compute latency
	AVG_RTT=$($PING_CMD $SVR_IP|awk -F"/" '/^rtt/{print $5}')
	
	#compute iget bandwidth utilization
	IGET_UTIL=$($IGET_CMD $GENOMIC_DATA $DEST|awk -F'|' '
	    BEGIN{i = 0;}
	    /^  */{
		gsub("/[^0-9.]/", "",$4);
		spd[i ++] = $4;
	    }
	    END{
		for(k in spd) sum += spd[k];
		print sum*8*100/(2*'$BANDWIDTH')"%";
	    }
	')	
	rm -rf $DEST
	sysctl -w vm.drop_caches=3 >> /dev/null

	#compute scp bandwidth utilization
	rm -rf $DEST
	SCP_UTIL=$($SCP_CMD $SVR_USR@$SVR_IP:$GENOMIC_DATA $DEST 2>&1 | awk '
	    /^Bytes per second/{print $7*8*100/(1024*1024*'$BANDWIDTH')"%"}
	')
	sysctl -w vm.drop_caches=3 >> /dev/null
	rm -rf $DEST
	
	#output
	echo -e "$(date +"%Y-%m-%d %T")\t$AVG_RTT\t$IGET_UTIL\t$SCP_UTIL" >> $OUTPUT
	
	#sleep
	sleep $((($INT + $INT_INCR * $i)))m
done
