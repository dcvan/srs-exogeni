#!/bin/bash

#basic settings
SVR_IP="152.54.14.13"
SVR_USR="pegasus-user"
SVR_PASS="pegasus"
NODE_USR="pegasus-user"
NODE_GRP="pegasus-user"
PEGASUS_HOME="/home/pegasus-user"
ROOT_HOME="/root"
RESULT="$PEGASUS_HOME/runtime.txt"
LOG="$ROOT/data-transfer.log"
ERR="$ROOT/data-transfer.err"

#iRODS information
IRODS_HOST="$SVR_IP"
IRODS_PORT="1247"
IRODS_USR="rods"
IRODS_PASS="pegasus"
IRODS_RESC="demoResc"
IRODS_ZONE="tempZone"
ICMD_BIN="$PEGASUS_HOME/iRODS/clients/icommands/bin/"
IRODSENV="$ROOT_HOME/.irods/.irodsEnv"

#target information
ICAT_TGT="genomicdata2"
SVR_TGT="~/genomicdata2"
DEST="$ROOT_HOME/genomicdata2"

#benchmark config
NUM_OF_ITERS=20 #number of benchmark iterations
INIT_INT=10 #initial interval(min)
INT_INCR=5 #interval increment after each iteration(min)


#ssh config
SSH_CONFIG="$ROOT_HOME/.ssh/config"

#iget config
IGET_THREAD_NUM=6

#scp config
SCP_CMD="sshpass -p $SVR_PASS scp -r"

#bbcp config
BBCP_URL="http://www.slac.stanford.edu/~abh/bbcp/bin/amd64_rhel60/bbcp"
BBCP_DEST="/usr/local/bin"
BBCP_CMD="sshpass -p $SVR_PASS bbcp -zr"

#set path
export PATH=$PATH:$BBCP_DEST:$ICMD_BIN
export HOME=$ROOT_HOME

#install sshpass, openssl openssl-devel
yum install -y sshpass openssl openssl-devel >> $LOG 2>> $ERR

#download bbcp
wget $BBCP_URL -P $BBCP_DEST >> $LOG 2>> $ERR
chmod +x $BBCP_DEST/bbcp

#config TCP parameters
sed -i 's/net.bridge.bridge.*/#&/g' /etc/sysctl.conf
cat >> /etc/sysctl.conf << EOF
### IPV4 specific settings
net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_sack = 0

### on systems with a VERY fast bus -> memory interface this is the big gainer
net.ipv4.tcp_rmem = 536870912 536870912 536870912
net.ipv4.tcp_wmem = 536870912 536870912 536870912
net.ipv4.tcp_mem = 536870912 536870912 536870912 

### CORE settings (mostly for socket and UDP effect)
net.core.rmem_max = 536870912 
net.core.wmem_max = 536870912
net.core.rmem_default = 536870912
net.core.wmem_default = 536870912
net.core.optmem_max = 536870912 
net.core.netdev_max_backlog = 1000000
EOF
sysctl -p /etc/sysctl.conf >> $LOG 2>> $ERR

#disable ssh strict host key checking
cat > $SSH_CONFIG << EOF
Host *
	StrictHostKeyChecking no
EOF
chmod 600 $SSH_CONFIG

#set iRODS environment
mkdir -m 755 $ROOT_HOME/.irods
cat > $IRODSENV << EOF
# iRODS server host name:
irodsHost '$IRODS_HOST'
# iRODS server port number:
irodsPort $IRODS_PORT
# Default storage resource name:
irodsDefResource '$IRODS_RESC'
# Home directory in iRODS:
irodsHome '/$IRODS_ZONE/home/$IRODS_USR'
# Current directory in iRODS:
irodsCwd '/$IRODS_ZONE/home/$IRODS_USR'
# Account name:
irodsUserName '$IRODS_USR'
# Zone:
irodsZone '$IRODS_ZONE'
EOF
chmod 600 $IRODSENV

#initialize iRODS client
iinit $IRODS_PASS >> $LOG 2>> $ERR

#create result file
touch $RESULT
chown $NODE_USR:$NODE_GRP $RESULT

echo -e "timestamp\tiget runtime\tscp runtime\tbbcp runtime" >> $RESULT
for ((i = 0;i < $NUM_OF_ITERS; i ++));do
	#transfer target using bbcp
	BBCP_RUNTIME=$({ time $BBCP_CMD $SVR_USR@$SVR_IP:$ICAT_TGT $ROOT_HOME >> $LOG 2>> $ERR; } 2>&1 | awk '/real.*/{print $2}' | awk -F'[ms]' '{print $1 * 60 + $2}')
	rm -rf $DEST && sysctl -w vm.drop_caches=3 > /dev/null
	#transfer target using iget
	IGET_RUNTIME=$({ time iget -r -N$IGET_THREAD_NUM $ICAT_TGT $DEST >> $LOG 2>> $ERR; } 2>&1 | awk '/real.*/{print $2}' | awk -F'[ms]' '{print $1 * 60 + $2}')
	rm -rf $DEST && sysctl -w vm.drop_caches=3 > /dev/null
	#transfer target using scp
	SCP_RUNTIME=$({ time $SCP_CMD $SVR_USR@$SVR_IP:$SVR_TGT $DEST >> $LOG 2>> $ERR; } 2>&1 | awk '/real.*/{print $2}' | awk -F'[ms]' '{print $1 * 60 + $2}')
	rm -rf $DEST && sysctl -w vm.drop_caches=3 > /dev/null

	echo -e "$(date +"%Y-%m-%d %T")\t$IGET_RUNTIME\t$SCP_RUNTIME\t$BBCP_RUNTIME" >> $RESULT
	sleep $((($INIT_INT + $INT_INCR * $i)))m
done

