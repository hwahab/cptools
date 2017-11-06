#!/bin/sh

# checkpoint gaia backup
#
# do a regular gaia backup and store additional info
# which could be helpful in case of complete system failure
#
# MGO / Oct 2017

# determine checkpoint version
CPVER=`rpm -qa | grep CPsuite | awk -F'-' '{print $2}'`

# load checkpoint environment
. /opt/CPshared/5.0/tmp/.CPprofile.sh

# variables
SERVER=<BACKUP-SERVER>
USERNAME=<USER>
DIRECTORY=/backup
TMPDIRECTORY=/var/log/tmp/backup
BKP_LOG=/var/log/sysbackup.log
HOSTNAME=`/bin/hostname`
SMC_STATE=`/opt/CPshrd-$CPVER/bin/cpstat mg | grep ^Status | awk '{ print $2 }'`
SMC_LOCK=`/opt/CPshrd-$CPVER/bin/cpstat mg | grep true | awk -F "|" '{ print $5 }'`
SMC_CHECK=`/opt/CPshrd-$CPVER/bin/cpstat fw | grep ^Policy | awk '{ print $3 }'`

# create a clean log file
if [ -f $BKP_LOG ];
then
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

# is this a management server?
if [ $SMC_CHECK == "-" ]; then
   IS_SMC="True"
   BKP_DAY=`date +%d`
else
   IS_SMC="False"
   BKP_DAY=`date +%W`
fi

# timestamp: backup begin
echo "---------------------------------------------------------" >> $BKP_LOG 2>&1
echo "Backup START `\date`" >> $BKP_LOG 2>&1

# create clean temporary directory
if [ -d $TMPDIRECTORY ]; then
   rm -r $TMPDIRECTORY >> $BKP_LOG 2>&1
fi
mkdir $TMPDIRECTORY >> $BKP_LOG 2>&1
cd $TMPDIRECTORY >> $BKP_LOG 2>&1

# store version information
if [ "$IS_SMC" == "True" ]; then
   $FWDIR/bin/fwm ver -f ver.txt
else
   $FWDIR/bin/fw ver -k -f ver.txt
fi
if [ -f $FWDIR/bin/installed_jumbo_take ]; then
   $FWDIR/bin/installed_jumbo_take >> ver.txt
fi

/bin/clish -c "lock database override" >> $BKP_LOG 2>&1
/bin/clish -c "show version all" >> ver.txt
/bin/clish -c "show asset all" >> ver.txt
cpinfo -y all -i >> ver.txt 2>&1

# system specific. maybe useful...
tar cvPf sys.tar /etc >> $BKP_LOG 2>&1
tar rvfP sys.tar /home/admin >> $BKP_LOG 2>&1
tar rvfP sys.tar /root >> $BKP_LOG 2>&1

# product specific. maybe useful.
if [ -f /var/opt/fw.boot/modules/fwkern.conf ]; then
   tar rvPf sys.tar /var/opt/fw.boot/modules/fwkern.conf >> $BKP_LOG 2>&1
fi
if [ -f $FWDIR/conf/discntd.if ]; then
   tar rvPf sys.tar $FWDIR/conf/discntd.if >> $BKP_LOG 2>&1
fi
if [ -f $FWDIR/conf/local.arp ]; then
   tar rvPf sys.tar $FWDIR/conf/local.arp >> $BKP_LOG 2>&1
fi
if [ -f /config/db/initial ]; then
   tar rvPf sys.tar /config/db/initial >> $BKP_LOG 2>&1
fi

# gaia config backup
/bin/clish -c "save configuration $HOSTNAME-config" >> $BKP_LOG 2>&1

# checkpoint system and product backup
printf "y \n" | /bin/backup -f $HOSTNAME-cpbackup >> $BKP_LOG 2>&1

# check where to find the backup file. maybe not necessary any more...
BACKUP_FILE=`find /var -type f -name $HOSTNAME-cpbackup.tgz`
if [ -f $BACKUP_FILE ]; then
   mv $BACKUP_FILE $TMPDIRECTORY/ >> $BKP_LOG 2>&1
fi

# create export file if thi sis a management server
if [ "$IS_SMC" == "True" ]; then
   echo "Dies ist ein Management Server" >> $BKP_LOG 2>&1
   if [ "$SMC_STATE" == "OK" ]; then
      echo "Primaerer Management Server, Export File erstellen" >> $BKP_LOG 2>&1
      if [ -n "$SMC_LOCK" ]; then
         echo "Datenbank durch Dashboard User gesperrt, trenne Verbindungen" >> $BKP_LOG 2>&1
         $FWDIR/bin/disconnect_client >> $BKP_LOG 2>&1
      fi
      $FWDIR/bin/upgrade_tools/migrate export -n $TMPDIRECTORY/$HOSTNAME-export.tgz >> $BKP_LOG 2>&1
   else
      echo "Logserver/Sekundaerer Management Server. Kein Export erstellt"
   fi
fi

# packaging...
tar cvf $HOSTNAME-$BKP_DAY.tar ver.txt sys.tar $HOSTNAME-config $HOSTNAME-cpbackup.tgz >> $BKP_LOG 2>&1
if [ -f $HOSTNAME-export.tgz ]; then
   tar rvf $HOSTNAME-$BKP_DAY.tar $HOSTNAME-export.tgz >> $BKP_LOG 2>&1
fi
md5sum $HOSTNAME-$BKP_DAY.tar > $HOSTNAME-$BKP_DAY.md5

# ...and upload
scp -q $TMPDIRECTORY/$HOSTNAME-$BKP_DAY.tar $USERNAME@$SERVER:$DIRECTORY/$HOSTNAME/$HOSTNAME-$BKP_DAY.tar >> $BKP_LOG 2>&1
scp -q $TMPDIRECTORY/$HOSTNAME-$BKP_DAY.md5 $USERNAME@$SERVER:$DIRECTORY/$HOSTNAME/$HOSTNAME-$BKP_DAY.md5 >> $BKP_LOG 2>&1

echo "---------------------------------------------------------" >> $BKP_LOG 2>&1
echo "Backup END `\date`" >> $BKP_LOG 2>&1
