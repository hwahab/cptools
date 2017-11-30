#!/bin/bash

# firewall configuration backup using cprid
# run on checkpoint management server
#
# also see sk101047
#
# mgo 2017

. /opt/CPshared/5.0/tmp/.CPprofile.sh

FW_IP=( 1.1.1.1 2.2.2.2 3.3.3.3 4.4.4.4 )
BKP_DAY=`date +%W`

for i in "${FW_IP[@]}"; do
   echo "Backup Firewall Configuration $i:"
   $CPDIR/bin/cprid_util -server $i -verbose rexec -rcmd clish -c "show configuration" > $i-$BKP_DAY
   $CPDIR/bin/cprid_util -server $i -verbose rexec -rcmd cpinfo -y all -i >> $i-$BKP_DAY
   echo ""
done


