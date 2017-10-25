#!/bin/sh

# Checkpoint GAIA Backup Skript
# Sichert Konfiguration und weitere wichtige Files (fwkern.conf etc.)
#
# Michael Goessmann Matos, NTT Com Security
# Januar 2016

# Checkpoint Version ermitteln
CPVER=`rpm -qa | grep CPsuite | awk -F'-' '{print $2}'`

# Checkpoint Enviroment-Variablen laden
. /opt/CPshrd-$CPVER/tmp/.CPprofile.sh

# Sonstige Variablen definieren
SERVER=<BACKUP-SERVER>
USERNAME=<USER>
DIRECTORY=/backup
TMPDIRECTORY=/var/log/tmp/backup
BKP_LOG=/var/log/sysbackup.log
HOSTNAME=`/bin/hostname`
SMC_STATE=`/opt/CPshrd-$CPVER/bin/cpstat mg | grep ^Status | awk '{ print $2 }'`
SMC_LOCK=`/opt/CPshrd-$CPVER/bin/cpstat mg | grep true | awk -F "|" '{ print $5 }'`
SMC_CHECK=`/opt/CPshrd-$CPVER/bin/cpstat fw | grep ^Policy | awk '{ print $3 }'`

# Ein sauberes Logfile erzeugen
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

# Ist dies ein Management Server? Wenn ja, dann Sicherung taeglich.
if [ $SMC_CHECK == "-" ]; then
   IS_SMC="True"
   BKP_DAY=`date +%d`
else
   IS_SMC="False"
   BKP_DAY=`date +%W`
fi

# Timestamp: Beginn der Datensicherung
echo "---------------------------------------------------------" >> $BKP_LOG 2>&1
echo "Backup START `\date`" >> $BKP_LOG 2>&1

# Ein sauberes Log Temporaeres Verzeichnis erzeugen
if [ -d $TMPDIRECTORY ]; then
   rm -r $TMPDIRECTORY >> $BKP_LOG 2>&1
fi
mkdir $TMPDIRECTORY >> $BKP_LOG 2>&1
cd $TMPDIRECTORY >> $BKP_LOG 2>&1

# Versionsinformationen sichern
if [ "$IS_SMC" == "True" ]; then
   /opt/CPsuite-$CPVER/fw1/bin/fwm ver -f ver.txt
else
   /opt/CPsuite-$CPVER/fw1/bin/fw ver -k -f ver.txt
fi
if [ -f $FWDIR/bin/installed_jumbo_take ]; then
   $FWDIR/bin/installed_jumbo_take >> ver.txt
fi

/bin/clish -c "lock database override" >> $BKP_LOG 2>&1
/bin/clish -c "show version all" >> ver.txt
/bin/clish -c "show asset all" >> ver.txt

# Systemspezifische Dinge sichern. Nicht zwingend notwendig, aber man weiss ja nie...
tar cvPf sys.tar /etc >> $BKP_LOG 2>&1
tar rvfP sys.tar /home/admin >> $BKP_LOG 2>&1
tar rvfP sys.tar /root >> $BKP_LOG 2>&1

# Produktspezifische Konfigurationen sichern
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

# Konfigurationssicherung
/bin/clish -c "save configuration $HOSTNAME-config" >> $BKP_LOG 2>&1

# Checkpoint Backup File erstellen
printf "y \n" | /bin/backup -f $HOSTNAME-cpbackup >> $BKP_LOG 2>&1

# Und wo hat er's hingeschrieben?
BACKUP_FILE=`find /var -type f -name $HOSTNAME-cpbackup.tgz`
if [ -f $BACKUP_FILE ]; then
   mv $BACKUP_FILE $TMPDIRECTORY/ >> $BKP_LOG 2>&1
fi

# Export erstellen, wenn dies ein Smartcenter ist
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

# Alles schoen verpacken...
tar cvf $HOSTNAME-$BKP_DAY.tar ver.txt sys.tar $HOSTNAME-config $HOSTNAME-cpbackup.tgz >> $BKP_LOG 2>&1
if [ -f $HOSTNAME-export.tgz ]; then
   tar rvf $HOSTNAME-$BKP_DAY.tar $HOSTNAME-export.tgz >> $BKP_LOG 2>&1
fi
md5sum $HOSTNAME-$BKP_DAY.tar > $HOSTNAME-$BKP_DAY.md5

# ...und auf den Backup Server schaufeln
scp -q $TMPDIRECTORY/$HOSTNAME-$BKP_DAY.tar $USERNAME@$SERVER:$DIRECTORY/$HOSTNAME/$HOSTNAME-$BKP_DAY.tar >> $BKP_LOG 2>&1
scp -q $TMPDIRECTORY/$HOSTNAME-$BKP_DAY.md5 $USERNAME@$SERVER:$DIRECTORY/$HOSTNAME/$HOSTNAME-$BKP_DAY.md5 >> $BKP_LOG 2>&1

# Aufraeumen
rm $TMPDIRECTORY/$HOSTNAME-$BKP_DAY.tar
rm $TMPDIRECTORY/$HOSTNAME-$BKP_DAY.md5
rm $TMPDIRECTORY/ver.txt
rm $TMPDIRECTORY/sys.tar
rm $TMPDIRECTORY/$HOSTNAME-config
rm $TMPDIRECTORY/$HOSTNAME-cpbackup.tgz
if [ -f $TMPDIRECTORY/$HOSTNAME-export.tgz ]; then
   rm $TMPDIRECTORY/$HOSTNAME-export.tgz
fi

echo "---------------------------------------------------------" >> $BKP_LOG 2>&1
echo "Backup END `\date`" >> $BKP_LOG 2>&1
