#!/bin/sh

# checkpoint mds backup
#
# purpose and function:
# backup a checkpoint multi domain management server and all it's management domains both locally 
# and to a backup server via scp. backups are stored locally in a fs structure (directory name = day-of-month) 
# below $BKP_DIR. remote backups consist of an archive containing all daily backups. 
# once a month (every 1st), a copy of the mds backup file is additionally transferred to the backup server.
#
# version 4
# september 28 2017
# mgo [djonz@posteo.de]

. /opt/CPshared/5.0/tmp/.CPprofile.sh

SERVER="REMOTE SERVER"
USERNAME="REMOTE USER"
DIRECTORY="REMOTE DIRECTORY"
BKP_TMP=/var/log/tmp/backup
BKP_DIR=/var/log/backup
BKP_LOG=/var/log/backup.log
BKP_DAY=`date +%d`
BKP_MON=`date +%b`

if [ -f $BKP_LOG ]; then
    if [ -f $BKP_LOG.2 ]; then
    	mv $BKP_LOG.2 $BKP_LOG.3
    fi
    if [ -f $BKP_LOG.1 ]; then
    	mv $BKP_LOG.1 $BKP_LOG.2
    fi
    if [ -f $BKP_LOG.0 ]; then
    	mv $BKP_LOG.0 $BKP_LOG.1
    fi
    mv $BKP_LOG $BKP_LOG.0
    cat /dev/null > $BKP_LOG
    chmod 644 $BKP_LOG
else
    touch $BKP_LOG
fi

echo "---------------------------------------------------------" >> $BKP_LOG 2>&1
echo "START of MDS Backup `\date`" >> $BKP_LOG 2>&1

if [ -d $BKP_TMP ]; then
	rm -rf $BKP_TMP
fi
mkdir $BKP_TMP
cd $BKP_TMP

$FWDIR/bin/fwm ver -f ver.txt
if [ -f $MDS_TEMPLATE/bin/installed_jumbo_take ]; then
	$MDS_TEMPLATE/bin/installed_jumbo_take >> ver.txt
else
	echo "No jumbo hf installed or installed_jumbo_take binary not found!"  >> ver.txt
fi
clish -c "lock database override" >> $BKP_LOG 2>&1
clish -c "show version all" >> ver.txt
cpinfo -y all >> ver.txt
clish -c "save configuration $HOSTNAME-config" >> $BKP_LOG 2>&1
tar czf system.tgz ver.txt $HOSTNAME-config >> $BKP_LOG 2>&1
rm ver.txt
rm $HOSTNAME-config

$FWDIR/scripts/mds_backup -b -l -L best >> $BKP_LOG 2>&1

for CMA in `$MDSVERUTIL AllCMAs`; do
	echo "Backing up CMA $CMA..." >> $BKP_LOG 2>&1
	mdsstop_customer $CMA
	mdsenv $CMA
    $FWDIR/bin/upgrade_tools/migrate export -n $BKP_TMP/$CMA >> $BKP_LOG 2>&1
    mdsstart_customer $CMA
done

tar cfz /var/log/tmp/daily-mds-backup.tgz $BKP_TMP/* >> $BKP_LOG 2>&1
scp -q /var/log/tmp/daily-mds-backup.tgz $USERNAME@$SERVER:$DIRECTORY/ >> $BKP_LOG 2>&1
rm /var/log/tmp/daily-mds-backup.tgz

scp -q $BKP_TMP/gtar $USERNAME@$SERVER:$DIRECTORY/ >> $BKP_LOG 2>&1
scp -q $BKP_TMP/gzip $USERNAME@$SERVER:$DIRECTORY/ >> $BKP_LOG 2>&1
scp -q $BKP_TMP/mds_restore $USERNAME@$SERVER:$DIRECTORY/ >> $BKP_LOG 2>&1

if [ "$BKP_DAY" == "1" ]; then
	scp -q $BKP_TMP/*.mdsbk.tgz $USERNAME@$SERVER:$DIRECTORY/$BKP_MON.mdsbk.tgz >> $BKP_LOG 2>&1
fi

if [ ! -d $BKP_DIR ]; then
	mkdir $BKP_DIR
fi
if [ ! -d $BKP_DIR/$BKP_DAY ]; then
	mkdir $BKP_DIR/$BKP_DAY
fi
mv $BKP_TMP/* $BKP_DIR/$BKP_DAY/

echo "END of MDS Backup `\date`" >> $BKP_LOG
