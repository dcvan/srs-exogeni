#!/bin/bash

#resources
ICAT_SRC="ftp://ftp.renci.org/pub/irods/releases/4.0.0/irods-icat-4.0.0-64bit-centos6.rpm"
IRODS_DB_PLUGIN_SRC="ftp://ftp.renci.org/pub/irods/releases/4.0.0/irods-database-plugin-postgres-1.0-centos6.rpm"
DEPENDENCIES="postgresql postgresql-server unixODBC perl authd postgresql-odbc fuse-devel openssl098e"
BBCP_SRC="http://www.slac.stanford.edu/~abh/bbcp/bin/amd64_rhel60/bbcp"
EXOME_1="http://people.renci.org/~escott/exomes/SRR824936_1.filt.fastq.gz"
EXOME_2="http://people.renci.org/~escott/exomes/SRR824936_2.filt.fastq.gz"
DATA_DIR="/var/lib/irods/genomicdata2"

#irods config
IRODS_HOME="/var/lib/irods/iRODS"
IRODS_DB_USER="irods"
IRODS_DB_PASS="irods"
IRODS_DB_TYPE="postgres"
IRODS_DB_PORT="5432"
IRODS_USER="rods"
IRODS_PASS="pegasus"
IRODS_CONF="/etc/irods/irods.config"
IRODS_SERVER_CONF="/etc/irods/server.config"
IRODS_SETUP_SCRIPT="./scripts/perl/irods_setup.pl"

#postgres config
POSTGRES_CONF="/var/lib/pgsql/data/pg_hba.conf"

#basic config
SVR_USER="pegasus-user"
SVR_PASS="$IRODS_PASS"
#HOST_IP=$(ifconfig eth1|grep "inet addr"|awk -F':' '{split($2, a, " "); print a[1]}')
HOST_IP=10.0.0.2
HOSTNAME=$(hostname)
LOOPBACK_IP="127.0.0.1"

#create pegasus user
useradd $SVR_USER
echo $SVR_PASS | passwd $SVR_USER --stdin

#change root's password
echo $SVR_PASS | passwd root --stdin

#overwrite /etc/hosts
cat > /etc/hosts << EOF
127.0.0.1 localhost
$HOST_IP $HOSTNAME
EOF

#download packages
wget $ICAT_SRC -P ~
wget $IRODS_DB_PLUGIN_SRC -P ~
wget $BBCP_SRC -P /usr/local/bin

#make bbcp executable
chmod +x /usr/local/bin/bbcp

#install dependencies
yum -y install $DEPENDENCIES

#initialize and start database server
/sbin/service postgresql initdb && /sbin/service postgresql start

#modify postgres config
sed -i "s/\(host *all *all *127.0.0.1\/32 *\)ident/\1trust/g" $POSTGRES_CONF
/sbin/service postgresql restart

#modify auth config
sed -i "s/\(server_args *= -t60 --xerror -os\) -E/\1/g" /etc/xinetd.d/auth

#set run level for authd
/sbin/chkconfig --level=3 auth on

#restart xinetd
/etc/init.d/xinetd restart

#install irods
rpm -i ~/*.rpm

#create irods role in postgres and grant privileges to create DB
su postgres -c "cd;psql -c \"create user $IRODS_DB_USER with password '$IRODS_DB_PASS';alter user $IRODS_DB_USER createdb;\""

#irods setup
sed -i "s/\(\$DATABASE_HOST = \).*/\1'$LOOPBACK_IP';/g" $IRODS_CONF
sed -i "s/\(\$DATABASE_ADMIN_PASSWORD = \).*/\1'$IRODS_DB_PASS';/g" $IRODS_CONF
echo "catalog_database_type $IRODS_DB_TYPE" >> $IRODS_SERVER_CONF

su irods -c "cd $IRODS_HOME;./irodsctl stop;perl $IRODS_SETUP_SCRIPT $IRODS_DB_TYPE $LOOPBACK_IP $IRODS_DB_PORT $IRODS_DB_USER $IRODS_DB_PASS" || exit 1; 

#initialize icommand
su irods -c "iadmin moduser $IRODS_USER password $IRODS_PASS;iinit $IRODS_PASS"

#create directory for genomic data
mkdir $DATA_DIR

#download genomic data
wget $EXOME_1 -P $DATA_DIR
wget $EXOME_2 -P $DATA_DIR

#unzip file
echo "Unzip genomic data ..."
gunzip $DATA_DIR/*.gz
chown -R irods:irods $DATA_DIR

#upload to icat server
echo "Upload genomic data to iCat ..."
su irods -c "iput -r $DATA_DIR"

#move to pegasus-user's home dir
echo "Move genomic data to pegasus-user's home directory..."
chown -R $SVR_USER $DATA_DIR 
mv $DATA_DIR /home/$SVR_USER

