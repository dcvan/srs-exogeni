#!/bin/bash

#basic settings
SVR_IP="152.54.14.13"
SVR_USR="pegasus-user"
SVR_PASS="pegasus"
NODE_USR="pegasus-user"
NODE_GRP="pegasus-user"
PEGASUS_HOME="/home/pegasus-user"
ICMD_BIN="$PEGASUS_HOME/iRODS/clients/icommands/bin/"
IRODSENV="$PEGASUS_HOME/.irods/.irodsEnv"
BENCHMARK="$PEGASUS_HOME/benchmark.sh"
RESULT="$PEGASUS_HOME/runtime.txt"

#iRODS information
IRODS_HOST="$SVR_IP"
IRODS_PORT="1247"
IRODS_USR="rods"
IRODS_PASS="pegasus"
IRODS_RESC="demoResc"
IRODS_ZONE="tempZone"

#target information
ICAT_TGT="genomicdata"
SVR_TGT="~/genomicdata"
DEST="$PEGASUS_HOME/genomicdata"

#iget config
IGET_THREAD_NUM=6;

#scp config
SCP_CMD="sshpass -p $SVR_PASS scp -r -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"

#install sshpass
yum install -y sshpass

#set iRODS environment
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

chown $NODE_USR:$NODE_GRP $IRODSENV
chmod 600 $IRODSENV

#create benchmark script
cat > $BENCHMARK << EOF
#!/bin/bash

PATH=\$PATH:$ICMD_BIN
IGET_THREAD_NUM=${1-6}
#initialize iRODS client
iinit $IRODS_PASS

#transfer target using iget
IGET_RUNTIME=\$({ time iget -r -N\$IGET_THREAD_NUM $ICAT_TGT $DEST; } 2>&1 | awk '/real.*/{print \$2}')
rm -rf $DEST
#transfer target using scp
SCP_RUNTIME=\$({ time $SCP_CMD $SVR_USR@$SVR_IP:$SVR_TGT $DEST; } 2>&1 | awk '/real.*/{print \$2}')
rm -rf $DEST

#save results
echo -e "iget runtime: \$IGET_RUNTIME\nscp runtime: \$SCP_RUNTIME" > $RESULT
EOF

chown $NODE_USR:$NODE_GRP $BENCHMARK
chmod 700 $BENCHMARK

su pegasus-user -c "$BENCHMARK $IGET_THREAD_NUM && rm $BENCHMARK"
