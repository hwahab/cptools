#!/bin/bash

# LOGWORK ORANGE - Disk Space Desaster Prevention
# Delete Checkpoint firewall logfiles older than $RETIME days
#
# dj0Nz
# June 2017

# variables
ORANGE=/var/log/logwork.log
RETIME="365"
TMPDIR=/var/log/tmp/logwork

# load Checkpoint enviroment
. /opt/CPshared/5.0/tmp/.CPprofile.sh

if [ -f $ORANGE ];
then
        if [ -f $ORANGE.2 ]; then
                mv $ORANGE.2 $ORANGE.3
        fi
        if [ -f $ORANGE.1 ]; then
                mv $ORANGE.1 $ORANGE.2
        fi
        if [ -f $ORANGE.0 ]; then
                mv $ORANGE.0 $ORANGE.1
        fi
        mv $ORANGE $ORANGE.0
        cat /dev/null > $ORANGE
        chmod 644 $ORANGE
fi

echo "---------------------------------------------------------" >> $ORANGE 2>&1
echo "[`\date`] Logwork Orange START" >> $ORANGE 2>&1

if [ -d $TMPDIR ]; then
   rm -r $TMPDIR
fi
mkdir $TMPDIR
cd $TMPDIR

NUM_FILES=`/usr/bin/find $FWDIR/log/ -type f -iname *\.log -mtime +$RETIME -print | wc -l` >> $ORANGE 2>&1

if [ $NUM_FILES -gt 0 ]; then
   echo "[`\date`] Removing files older than $RETIME days..." >> $ORANGE 2>&1
   for EXT in logptr log log_stats logaccount_ptr loginitial_ptr; do
       echo ""
       echo "Removing *.$EXT files"
       /usr/bin/find $FWDIR/log/ -type f -iname *\.$EXT -mtime +$RETIME -print | xargs rm >> $ORANGE 2>&1
   done
else
   echo "Nothing to remove yet..." >> $ORANGE 2>&1
fi

echo ""
echo "[`\date`] Logwork Orange END" >> $ORANGE
