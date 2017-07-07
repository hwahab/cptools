#!/bin/bash
#
# gaia config to vsx provisioning conversion
#
# export gaia config with show configuration or save config <file>
# needs vsx provisioning tool on management server for vs creation
# see sk100645
#
# on the roadmap for next version:
# - input checking 
# - virtual router handling
# - topology input if autocalc set to false
# - cisco asa migration
# 
# version 2.0
# mgo
# june 30th 2017

echo "gaia config to vs converter"
echo "---------------------------"
echo ""
echo "reads checkpoint gaia configuration and creates a script which can be used as input for"
echo "the checkpoint vsx provisioning tool (sk100645) to provision a virtual firewall"
echo "on a running vsx gateway or cluster. currently, only regular interfaces and"
echo "interfaces connected to virtual switches are supported. change provisioning"
echo "script if warp interfaces leading to virtual routers are needed."
echo "" 
echo "please enter main provisioning parameters"
echo ""

# parameter input
read -p "gaia config file name: " gaiacfg
if [ "$gaiacfg" == "" ]; then
   echo "no input file specified. exiting."
   exit 1
fi
if [ ! -f "$gaiacfg" ]; then
   echo "input file not found. exiting." 
   exit 1
fi
read -p "virtual system name: " vs
if [ "$vs" == "" ]; then
   echo "no virtual system specified. exiting."
   exit 1
fi
read -p "vsx gateway name: " vsxgw
if [ "$vsxgw" == "" ]; then
   echo "no vsx gateway specified. exiting."
   exit 1
fi
read -p "vs main ip (usually external ip): " mainip
if [ "$mainip" == "" ]; then
   echo "no main ip specified. exiting."
   exit 1
fi
read -p "autocalc topology (recommended)? [Y/n] " yn
case $yn in
    [Nn] ) 	autocalc="false"
    		;;
    * ) 	autocalc="true"
    		;;
esac
read -p "provisioning script file name: " output_file
if [ "$output_file" == "" ]; then
   echo "no output file name specified. exiting."
   exit 1
fi

# main program
echo ""
echo "entering provisioning script creation"

# first: echo transaction begin and vs creation commands
echo "transaction begin" > $output_file
echo "add vd name $vs vsx $vsxgw type vs main_ip $mainip calc_topo_auto $autocalc" >> $output_file

while read -r line
do
	line1=($line)
	if [ "${line1[1]}" == "interface" ]; then
		if [ "${line1[3]}" == "ipv4-address" ]; then
			echo ""
			echo "current interface: ${line1[2]} [${line1[4]}/${line1[6]}]"
			echo -n "create interface? [Y/n]? "
			IFS="" read -r create  </dev/tty
		    if [ ! "$create" == "n" ]; then
		    	echo -n "connect to virtual switch? [y/N] "
		    	IFS="" read -r warp  </dev/tty
		    	case $warp in
        			[Yy] )	iftype="leads_to"
        					echo -n "enter virtual switch name: "
        					IFS="" read -r ifname </dev/tty
        					;;
        			* ) 	iftype="name"
        					echo -n "new interface name (current: ${line1[2]}): "
        					IFS="" read -r ifname  </dev/tty
        					;;
    			esac
				echo -n "use current ip ${line1[4]} (answer no to enter cluster ip) [Y/n]? " 
				IFS="" read -r clusterip </dev/tty
    			case $clusterip in
        			[Nn] ) 	echo -n "enter cluster ip: "
        					IFS="" read -r if_ip </dev/tty
        					;;
        				* ) if_ip="${line1[4]}"
        					;;
    			esac
				mask="${line1[6]}"
				echo "add interface vd $vs $iftype $ifname ip $if_ip/$mask" >> $output_file
			fi
		fi
	fi
	if [ "${line1[1]}" == "static-route" ]; then
		if [ ! "${line1[3]}" == "comment" ]; then
			dest="${line1[2]}"
			nexthop="${line1[6]}"
			echo "add route vd $vs destination $dest next_hop $nexthop" >> $output_file
		fi
	fi
done < $gaiacfg

echo "transaction end" >> $output_file

echo ""
echo "provisioning file $output_file created. please carefully check the commands" 
echo "(documentation in sk100645), transfer to management server and create vs using"
echo "vsx provisioning tool."
echo ""
if [ "$autocalc" == "false" ]; then
	echo "topology autocalculation has been set to off. please configure"
	echo "topology in smartdashboard after vs is provisioned."
fi

