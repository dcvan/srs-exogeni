#!/bin/bash

#basic info
NODE_USR="pegasus-user"
NODE_GRP="pegasus-user"
PEGASUS_HOME="/home/pegasus-user"
EXON_HOME="$PEGASUS_HOME/genomics/wf_exon_irods"
CATALOG="$EXON_HOME/replica.cat"
LOG="$PEGASUS_HOME/wf.log"
BOOTSTRAP="$PEGASUS_HOME/bootstrap.sh"
JOB_PATH="$PEGASUS_HOME/genomics/wf_exon_irods/pegasus-user/pegasus/exonalignwf/run0001"
ICMD_BIN="$PEGASUS_HOME/iRODS/clients/icommands/bin"

#genomic data info
OLD_GENE_DIR="genomicdata"
NEW_GENE_DIR="genomicdata2"
OLD_GENE_PATTERN="in\([0-9]*\).fastq"
NEW_GENE_PATTERN="SRR824936_\1.filt.fastq"

#iRODS config
IRODSENV="$PEGASUS_HOME/.irods/.irodsEnv"
IRODS_HOST="152.54.14.13"
IRODS_PORT="1247"
IRODS_USR="rods"
IRODS_PASS="pegasus"
IRODS_RESC="demoResc"
IRODS_ZONE="tempZone"

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

irodsPassword '$IRODS_PASS'
EOF

chmod 600 $IRODSENV 
chown -R $NODE_USR:$NODE_GRP $IRODSENV 

#create bootstrap script
cat > $BOOTSTRAP << EOF
#!/bin/bash

PATH=\$PATH:$ICMD_BIN
iinit $IRODS_PASS
cd $EXON_HOME
./cleanup.sh 2> $LOG
python gendag.py > dax.xml 2> $LOG
./genplan.sh 2> $LOG
pegasus-run $JOB_PATH 2> $LOG
EOF

chmod 700 $BOOTSTRAP
chown -R $NODE_USR:$NODE_GRP $BOOTSTRAP

#direct the workflow to the new genomic data
sed -i "s/$OLD_GENE_DIR/$NEW_GENE_DIR/g;s/$OLD_GENE_PATTERN/$NEW_GENE_PATTERN/g" $CATALOG 

#run the workflow
su pegasus-user -c "$BOOTSTRAP"
