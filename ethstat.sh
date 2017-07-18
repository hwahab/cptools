#!/bin/sh

# quick check eth link
# Michael Goessmann Matos, NTT Com Security

#ETH_LIST=`ifconfig -a | grep eth | cut -f 1 -d " " | grep -v '\.' | tr '\n' ' '`
ETH_LIST=`ifconfig -a | egrep -i 'eth|mgmt|sync' | grep -v bond | cut -f 1 -d " " | grep -v '\.' | tr '\n' ' '`

echo ""
echo "Ethernet Interface Status"
echo ""

for ETH in $ETH_LIST; do

        LINK=`ethtool $ETH | grep Link | cut -f 2 -d ":" | tr -d " "`
        if [ "$LINK" == "yes" ]
        then
                SPEED=`ethtool $ETH | grep Speed | cut -f 2 -d ":" | tr -d " "`
                DUPLEX=`ethtool $ETH | grep Duplex | cut -f 2 -d ":" | tr -d " "`
                HWADDR=`ifconfig $ETH | egrep -i 'eth|mgmt|sync' | awk '{ print $5 }'`
                echo -e "$ETH:\tconnected at $SPEED $DUPLEX\t[$HWADDR]"
        else
                echo -e "$ETH:\tnot connected"
        fi

done

echo ""
