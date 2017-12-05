#!/bin/bash

# quick and dirty firewall configuration backup
# also see sk101047
# mgo 2017

. /opt/CPshared/5.0/tmp/.CPprofile.sh

FW=(`(echo localhost; echo "-t network_objects -s class='cluster_member'|type='gateway' -a -pf"; echo "-q") | queryDB_util | grep "Object Name" | awk '{print $3}' | tr '\n' ' '`)

for i in "${FW[@]}"; do
   echo "backup firewall configuration $i:"
   $CPDIR/bin/cprid_util -server $i -verbose rexec -rcmd clish -c "show configuration" > $i.cfg
   echo ""
done

