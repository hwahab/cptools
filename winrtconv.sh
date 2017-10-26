#!/bin/bash
#
# windows to gaia static routes conversion
#
# export windows static routes with "route print > routes.txt"
# eliminate all comments or other crap, only routing entries allowed
# also, check if there are broadcast, multicast and local routes
# in input file and delete relevant line
#
# function mask2cdr found at stackoverflow...
#
# version 1.0
# oct 26 2017
# mgo [djonz@posteo.de]

# check input parameters
if [ "$1" == "" ]; then
echo "no input file specified. exiting."
exit 1
fi
if [ ! -f "$1" ]; then
echo "input file not found. exiting."
exit 1
fi

# function to convert subnet mask to mask bits
mask2cdr ()
{
   local x=${1##*255.}
   set -- 0^^^128^192^224^240^248^252^254^ $(( (${#1} - ${#x})*2 )) ${x%%.*}
   x=${1%%$3*}
   echo $(( $2 + (${#x}/4) ))
}

dos2unix $1
rt="$1"

while read -r line
do
line1=($line)
echo "${line1[0]}/$(mask2cdr ${line1[1]}) ${line1[2]}"
done < $rt
