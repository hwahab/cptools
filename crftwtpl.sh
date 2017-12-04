#!/bin/sh

# checkpoint gaia - create ftw template file
#
# to recover a rma machine:
# - freshinstall
# - run ftw using config_system -f <output of this script>
# - then restore config (cp restore or load configuration file)
#
# mgo / dec 2017

# load checkpoint environment
. /opt/CPshared/5.0/tmp/.CPprofile.sh

# variables
TMPDIRECTORY=/var/log/tmp/
SMC_CHECK=`cpstat fw | grep ^Policy | awk '{ print $3 }'`
CXL_STATE=`cphaprob state | awk '{ if (NR==2) print $1 }'`
SIC_KEY="abc123"
ADM_HASH=`clish -c "show configuration" | grep 'user.admin.password-hash' | awk '{ print $5 }'`

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

# create input file
cd $TMPDIRECTORY
config_system -t $HOSTNAME.input
sed -i 's/#.*$//;/^$/d' $HOSTNAME.input

while read -r line
do
   case "$line" in
       "install_security_gw=") echo $line\"$IS_GW\" >> $HOSTNAME.template;;
       "gateway_cluster_member=") echo $line\"$IS_CLUSTER\" >> $HOSTNAME.template;;
       "install_security_managment=") echo $line\"$IS_SMC\" >> $HOSTNAME.template;;
       "ftw_sic_key=") echo $line\"$SIC_KEY\" >> $HOSTNAME.template;;
       "admin_hash=''") echo "admin_hash="\'$ADM_HASH\' >> $HOSTNAME.template;;
       "hostname=") echo $line\"$HOSTNAME\" >> $HOSTNAME.template;;
       *) echo $line >> $HOSTNAME.template
   esac
done < $HOSTNAME.input
rm $HOSTNAME.input
