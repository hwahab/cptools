#!/bin/sh

# checkpoint gaia - create ftw template file
# purpose: quick recover a rma machine using
# ftw template and saved configuration or backup
#
# MGO / Oct 2017

# determine checkpoint version
CPVER=`rpm -qa | grep CPsuite | awk -F'-' '{print $2}'`

# load checkpoint environment
. /opt/CPshared/5.0/tmp/.CPprofile.sh

# variables
TMPDIRECTORY=/var/log/tmp/
HOSTNAME=`/bin/hostname`
SMC_STATE=`cpstat mg | grep ^Status | awk '{ print $2 }'`
SMC_CHECK=`cpstat fw | grep ^Policy | awk '{ print $3 }'`
CXL_STATE=`cphaprob state | awk '{ if (NR==2) print $1 }`

# check input file
if [ "$1" == "" ]; then
   echo "no input file specified. exiting."
   exit 1
fi
if [ ! -f "$1" ]; then
   echo "input file not found. exiting."
   exit 1
fi

# is this a management server or a gateway?
if [ $SMC_CHECK == "-" ]; then
   IS_SMC="true"
   IS_GW="false"
else
   IS_SMC="false"
   IS_GW="true"
fi

# should run on gateway only
if [ $IS_GW == "false" ]; then
   echo "not a gateway. exiting."
   exit 1
fi

# is this a cluster?
if [ $CXL_STATE == "Cluster" ]; then
   IS_CLUSTER="true"
else
   IS_CLUSTER="false"
fi

while read -r line
do
  line1=($line)
  if [ "${line1[0]}" == "install_security_gw" ]; then
     cat $line $IS_GW > $line1
     echo $line1
  fi
done < $input_file
