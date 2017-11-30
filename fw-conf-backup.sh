#!/bin/bash

# firewall configuration backup using cprid
# mgo 2017


. /opt/CPshared/5.0/tmp/.CPprofile.sh

FW=( fw1 fw2 fw3 fw4 )
BKP_DAY=`date +%W`

for i in "${FW[@]}"; do
   echo "Backup Firewall Configuration $i:"
   $CPDIR/bin/cprid_util -server $i -verbose rexec -rcmd clish -c "show configuration" > $i-$BKP_DAY
   $CPDIR/bin/cprid_util -server $i -verbose rexec -rcmd cpinfo -y all -i >> $i-$BKP_DAY
   echo ""
done


