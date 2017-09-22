#!/bin/sh

# MDS Backup 4.0
# New in this version:
# - improved command line arguments to reflect new version capabilities
# - migrate export to backup management domains (instead of copying directories)
# - place daily backup locally, retaining one month (1 backup per day-of-month)
# - additional daily copy of backup files to scp server
# - additional monthly (at 1st) copy of mds backup file to scp server
# MGO / Sep 2017

. /opt/CPshared/5.0/tmp/.CPprofile.sh

SERVER="REMOTE SERVER"
USERNAME="REMOTE USER"
DIRECTORY="REMOTE DIRECTORY"
BKP_TMP=/var/log/tmp/backup
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
/bin/clish -c "lock database override" >> $BKP_LOG 2>&1
/bin/clish -c "show version all" >> ver.txt
/bin/clish -c "save configuration $HOSTNAME-config" >> $BKP_LOG 2>&1
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

if [ "$BKP_DAY" == "1" ]; then
	scp -q $BKP_TMP/*.mdsbk.tgz $USERNAME@$SERVER:$DIRECTORY/$BKP_MON.mdsbk.tgz >> $BKP_LOG 2>&1
fi

if [ ! -d /var/log/backup ]; then
	mkdir /var/log/backup
fi
if [ ! -d /var/log/backup/$BKP_DAY ]; then
	mkdir /var/log/backup/$BKP_DAY
fi
mv $BKP_TMP/* /var/log/backup/$BKP_DAY/

echo "END of MDS Backup `\date`" >> $BKP_LOG
