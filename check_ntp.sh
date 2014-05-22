#!/bin/sh 

# kin @ agava
# Fri 17 Jan 2014

# Rewrite Thu 22 May 2014
# Now it's not a stream filter anymore, but rather a nagios check.

# Project S1
# Program check_ntp
# Purpose: Check if NTP server is an amplifying one.

iterate=2

flag_length=0

ntpdc=$( which ntpdc 2>/dev/null )
[ $ntpdc ] || ntpdc=/usr/sbin/ntpdc

# read -r ip
ip="$1"

for ((i=0; i<$iterate; i++))
do
    ntp_reply="$ntp_reply""$( $ntpdc -n -c monlist $ip 2>/dev/null )"
    status=$(($status + $?))
done

flag_length=${#ntp_reply}

if
    [ $flag_length -gt 0 ]
then
    # echo -e $ip
    echo "Critical: NTP on $ip -- long response."
    exit 2
else
    echo "Good: NTP on $ip -- no response."
    exit 0 
fi


