#!/bin/bash
#
# cisco asa to checkpoint object migration tool
#
#########################################################################
#                                                                       #
# ATTENTION! THIS PROGRAM IS NOT FINISHED AT ALL, USE AT YOUR OWN RISK! #
#                                                                       #
#########################################################################
#
# This program reads lines from a cisco asa config and
# writes appropriate dbedit commands to output file <input-file>.dbedit
#
# may be imported afterwards using
# dbedit -local -globallock -f <input-file>.dbedit 
#
# preparation (workaround):
#
# create cisco standard services in checkpoint db
# use following dbedit commands:
#
# create service_group domain
# modify services domain type group
# modify services domain comments "migrated from asa config"
# addelement services domain '' services:domain-tcp
# addelement services domain '' services:domain-udp
# update services domain
# create tcp_service sqlnet
# modify services sqlnet port 1521
# modify services sqlnet comments "migrated from asa config"
# update services sqlnet
# create service_group icmp-services
# modify services icmp-services type group
# modify services icmp-services comments "migrated from asa config"
# addelement services icmp-services '' services:time-exceeded
# addelement services icmp-services '' services:dest-unreach
# addelement services icmp-services '' services:echo-request
# update services icmp-services
# update_all
# savedb
#
# or create services manually
# 
# open issues:
# - work around workaround
# - port objects in object groups
# - service name instead of port in service objects
# - enhanced error handling and syntax checking
# - use icmp-proto instead of "icmp"
# - read arrays word by word (exakt matching)
# - convert policies
# - rewrite in python
# 
# version 2.0
# april 24th 2017
# mgo [djonz@posteo.de]

# check input file
if [ "$1" == "" ]; then
   echo "no input file specified. exiting."
   exit 1
fi
if [ ! -f "$1" ]; then
   echo "input file not found. exiting."
   exit 1
fi

# create logfile, rotate if already there
logfile=migasa.log
if [ -f $logfile ];
then
        if [ -f $logfile.2 ]; then
                mv $logfile.2 $logfile.3
        fi
        if [ -f $logfile.1 ]; then
                mv $logfile.1 $logfile.2
        fi
        if [ -f $logfile.0 ]; then
                mv $logfile.0 $logfile.1
        fi
        mv $logfile $logfile.0
        cat /dev/null > $logfile
        chmod 644 $logfile
else
        touch $logfile
fi

# print start mark
echo "" >> $logfile
echo "asa to cp migration tool v1.0" >> $logfile
echo "migrate start at `date`" >> $logfile
echo "asa to cp migration tool v1.0 starting..."

# sourcing checkpoint environment 
. /opt/CPshared/5.0/tmp/.CPprofile.sh
    
# check if this is a checkpoint management machine
if [ -f /bin/rpm ]; then
   CPVER=`rpm -qa | grep CPsuite | awk -F'-' '{print $2}'`
   if [ "$CPVER" == "" ]; then
      echo "exited. is this is a checkpoint management server?"
      exit 1
   else
      SMC_CHECK=`/opt/CPshrd-$CPVER/bin/cpstat mg | grep ^Product | awk '{ print $6 }'`
   fi
   if [ "$SMC_CHECK" != "Management" ]; then
      echo "exited. is this is a checkpoint management server?"
      exit 1
   else
      echo "running on checkpoint $CPVER management server." >> $logfile
   fi
else
   echo "exited. is this is a checkpoint management server?"
   exit 1
fi

# converting input file to unix format
dos2unix -o "$1" >> $logfile 2>&1

# remove leading spaces from cisco config file
input_check=`cat $1 | sed -e 's/^[ \t]*//' > $1.tmp`
if [ "$input_check" == "" ]; then
   input_file="$1.tmp"
else
   echo "ups. error converting input file. exiting."
   exit 1
fi

# defining output file and removing old one
output_file=$1.dbedit
if [ -f $output_file ]; then
   echo "removing previous output file $output_file" >> $logfile
   rm $output_file
fi 

# record existing services and objects
declare -a cp_services
declare -a cp_objects
cp_services=`echo -e "query services\n-q\n" | dbedit -local | grep 'Object Name'| awk '{print $3}'`
cp_objects=`echo -e "query network_objects\n-q\n" | dbedit -local | grep 'Object Name'| awk '{print $3}'`

# first run: catch network and service objects
echo "" >> $logfile
echo "first run: create network and service objects" >> $logfile
echo "" >> $logfile
while read -r line
do
  line1=($line)
  if [ "${line1[0]}" == "object" ]; then
     if [[ "${line1[1]}" == "network" ]]; then
        if [[ ! "${cp_objects[@]}" =~ "${line1[2]}" ]]; then
           obj_name="${line1[2]}"
           # bad programming style but handy: read next line
           read -r line
           line2=($line)
           if [ "${line2[0]}" == "host" ]; then
              obj_ip="${line2[1]}"
              echo "create host_plain $obj_name" >> $output_file
              echo "modify network_objects $obj_name ipaddr $obj_ip" >> $output_file
              echo "modify network_objects $obj_name color black" >> $output_file
              echo "modify network_objects $obj_name comments "migrated from asa config"" >> $output_file
              echo "update network_objects $obj_name" >> $output_file
           fi
           if [ "${line2[0]}" == "subnet" ]; then
              obj_ip="${line2[1]}"
              obj_mask="${line2[2]}"
              echo "create network $obj_name" >> $output_file
              echo "modify network_objects $obj_name ipaddr $obj_ip" >> $output_file
              echo "modify network_objects $obj_name netmask $obj_mask" >> $output_file
              echo "modify network_objects $obj_name color black" >> $output_file
              echo "modify network_objects $obj_name comments "migrated from asa config"" >> $output_file
              echo "update network_objects $obj_name" >> $output_file
           fi
        else
           echo "network object ${line1[2]} already exists in cp database." >> $logfile
        fi
     fi
     if [ "${line1[1]}" == "service" ]; then
        obj_name="${line1[2]}"
        read -r line
        line2=($line)
        if [ "${line2[1]}" == "tcp" ]; then
           obj_svc_type="tcp_service"
        elif [ "${line2[1]}" == "udp" ]; then
           obj_svc_type="udp_service"
        else
           echo "Service $obj_name: Protocol not defined" >> $logfile
        fi
        if [ "${line2[3]}" == "eq" ]; then
           obj_svc_port="${line2[4]}"
           if [[ ! "${cp_services[@]}" =~ "$obj_name" ]]; then
              echo "create $obj_svc_type $obj_name" >> $output_file
              echo "modify services $obj_name port $obj_svc_port" >> $output_file
              echo "modify services $obj_name color black" >> $output_file
              echo "modify services $obj_name comments "migrated from asa config"" >> $output_file
              echo "update services $obj_name" >> $output_file
           else
              echo "existing ${line2[1]} service $obj_name not created" >> $logfile
           fi
        fi
        if [ "${line2[3]}" == "range" ]; then
           obj_svc_port1="${line2[4]}"
           obj_svc_port2="${line2[5]}"
           if [[ ! "${cp_services[@]}" =~ "$obj_name" ]]; then
              echo "create $obj_svc_type $obj_name" >> $output_file
              echo "modify services $obj_name port $obj_svc_port1-$obj_svc_port2" >> $output_file
              echo "modify services $obj_name color black" >> $output_file
              echo "modify services $obj_name comments "migrated from asa config"" >> $output_file
              echo "update services $obj_name" >> $output_file
           else
              echo "existing ${line2[1]} service $obj_name not created" >> $logfile
           fi
        fi
     fi
  fi
  if [ "${line1[0]}" == "port-object" ]; then
     svcname="${line1[2]}"
     if [[ ! "${portobj[@]}" =~ "$svcname" ]]; then
        portobj=("${portobj[@]}" "$svcname")
        if [[ "${cp_services[@]}" =~ "$svcname" ]]; then
           echo "existing service $svcname not created" >> $logfile
        else
           echo "port-object $svcname not created. config line: ${line1[*]}" >> $logfile
        fi
     fi
  fi
  if [ "${line1[0]}" == "service-object" ] && [ "${line1[1]}" != "object" ]; then
     if [ "${line1[1]}" == "icmp" ]; then
        svcname="${line1[1]}"
        if [[ ! "${portobj[@]}" =~ "$svcname" ]]; then
           portobj=("${portobj[@]}" "$svcname")
           echo "service-object $svcname not created. config line: ${line1[*]}" >> $logfile
        fi
     else  
        svcname="${line1[4]}"
        if [[ ! "${portobj[@]}" =~ "$svcname" ]]; then
           portobj=("${portobj[@]}" "$svcname")
           if [[ "${cp_services[@]}" =~ "$svcname" ]]; then
              echo "existing service $svcname not created" >> $logfile
           else
              check=`grep $svcname /etc/services | grep ${line1[1]} | sed 's/\// /g' | awk '{print $2}'`
              if [ "$check" == "" ]; then
                 echo "${line1[1]} service $svcname does not exist in services file" >> $logfile
              fi
           fi
        fi
     fi
  fi
done < $input_file

# second run: catch network and service groups
echo "" >> $logfile
echo "second run: create network and service groups" >> $logfile
echo "" >> $logfile
error_count=0
declare -a missing_service
declare -a grp_to_check
while read -r line
do
  line1=($line)
  if [ "${line1[0]}" == "access-list" ]; then
     if [[ ! "${cp_objects[@]}" =~ "$grp_name" ]] && [[ ! "${cp_services[@]}" =~ "$grp_name" ]]; then
        case "$grp_type" in 
           network) echo "update network_objects $grp_name"  >> $output_file;;
           service) echo "update services $grp_name"  >> $output_file;;
        esac
     fi
     echo "" >> $logfile
     echo "the following services were missing and should be created/checked:" >> $logfile
     echo "" >> $logfile
     for svc in "${missing_service[@]}"; do
        if [ "$svc" != "" ]; then
           echo $svc >> $logfile
        fi
     done
     echo "" >> $logfile
     echo "also, check their memberships to the following groups:" >> $logfile
     echo "" >> $logfile
     for grp in "${grp_to_check[@]}"; do
        if [ "$grp" != "" ]; then
           echo $grp >> $logfile
        fi
     done
     echo "update_all" >> $output_file
     echo "savedb" >> $output_file
     echo "" >> $logfile
     echo "migrate script stopped at `date`" >> $logfile
     rm $1.tmp
     echo "done. import config using \"dbedit -local -globallock -f $output_file\""
     exit
  fi
  if [ "${line1[0]}" == "object-group" ]; then
     case "$grp_type" in 
        network) echo "update network_objects $grp_name" >> $output_file;;
        service) echo "update services $grp_name" >> $output_file;;
     esac
     grp_name="${line1[2]}"
     grp_type="${line1[1]}"
     grp_service="${line1[3]}"
     if [[ ! "${cp_objects[@]}" =~ "${line1[2]}" ]] && [[ ! "${cp_services[@]}" =~ "${line1[2]}" ]]; then
        case "$grp_type" in 
           network) echo "create network_object_group $grp_name" >> $output_file
                    echo "modify network_objects $grp_name comments "migrated from asa config"" >> $output_file
           ;;
           service) echo "create service_group $grp_name" >> $output_file
                    echo "modify services $grp_name type group" >> $output_file
                    echo "modify services $grp_name comments "migrated from asa config"" >> $output_file
           ;;
        esac
        create_objects="yes"
     else
        echo "existing group object $grp_name not created!" >> $logfile
        create_objects="no"
     fi
  fi
  if [[ "$grp_type" == "network" ]] && [[ "$create_objects" == "yes" ]]; then
     if [ "${line1[0]}" == "network-object" ]; then
        if [ "${line1[1]}" == "object" ]; then
           grp_member="${line1[2]}"
           echo -e "addelement network_objects $grp_name '' network_objects:$grp_member" >> $output_file
        else
           echo "group: $grp_name: group member without object. config line: ${line1[*]}" >> $logfile
        fi
     fi
  fi
  if [[ "$grp_type" == "service" ]] && [[ "$create_objects" == "yes" ]]; then
     if [ "${line1[0]}" == "service-object" ]; then
        if [ "${line1[1]}" == "object" ]; then
           grp_member="${line1[2]}"
           if [ "$grp_member" == "www" ]; then
              grp_member="http"
           fi
           if [ "$grp_member" == "ldaps" ]; then
              grp_member="ldap-ssl"
           fi
           if [ "$grp_member" == "netbios-ssn" ]; then
              grp_member="nbsession"
           fi
           if [ "$grp_member" == "netbios-dgm" ]; then
              grp_member="nbdatagram"
           fi
           if [ "$grp_member" == "netbios-ns" ]; then
              grp_member="nbname"
           fi
           echo -e "addelement services $grp_name '' services:$grp_member" >> $output_file
        elif [ "${line1[1]}" == "icmp" ]; then
           echo -e "addelement services $grp_name '' services:icmp-services" >> $output_file
        elif [[ "${cp_services[@]}" =~ "${line1[4]}" ]]; then
           grp_member="${line1[4]}"
           echo -e "addelement services $grp_name '' services:$grp_member" >> $output_file
        else
           grp_member="${line1[4]}"
           if [[ ! "${missing_service[@]}" =~ "$grp_member" ]]; then
              missing_service=("${missing_service[@]}" "$grp_member")
           fi
           if [[ ! "${grp_to_check[@]}" =~ "$grp_name" ]]; then
              grp_to_check=("${grp_to_check[@]}" "$grp_name")
           fi
        fi
     fi 
     if [ "${line1[0]}" == "port-object" ]; then
        if [ "${line1[1]}" == "eq" ]; then
           grp_member="${line1[2]}"
           if [ "$grp_member" == "www" ]; then
              grp_member="http"
           fi
           if [ "$grp_member" == "ldaps" ]; then
              grp_member="ldap-ssl"
           fi
           if [ "$grp_member" == "netbios-ssn" ]; then
              grp_member="nbsession"
           fi
           if [ "$grp_member" == "netbios-dgm" ]; then
              grp_member="nbdatagram"
           fi
           if [ "$grp_member" == "netbios-ns" ]; then
              grp_member="nbname"
           fi
           if [[ "${cp_services[@]}" =~ "$grp_member" ]]; then
              echo -e "addelement services $grp_name '' services:$grp_member" >> $output_file
           else
              echo -e "group $grp_name: add port object $grp_member manually. config line: ${line1[*]}" >> $logfile
           fi
        else
           echo -e "group $grp_name: no port object. config line: ${line1[*]}" >> $logfile
        fi
     fi       
  fi
done < $input_file
  
