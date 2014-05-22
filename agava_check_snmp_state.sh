#!/bin/sh

# ------------------------------------------------------------------------------
# kin @ agava Wed 09 Apr 2014
# ------------------------------------------------------------------------------
# This script goes in pair with another, server-side one. SNMP is the
# interchange protocol, snmpd.conf set accordingly. So you may think of it as a
# three-piece system.
#
# Currently, only SNMP v1 is supported -- to much regret.
# ------------------------------------------------------------------------------

if test $# -eq 0
then
    echo "Usage: agava_check_snmp_state -H HOSTNAME [-C COMMUNITY] [-t TIMEOUT]"
    exit 3
fi

while getopts H:C:t: VARNAME
do
    case $VARNAME in
        (H) hostaddress="$OPTARG" ;;
        (C) snmpcommunity="$OPTARG" ;;
        (t) timeout="$OPTARG" ;; 
    esac
done

if test ! "$hostaddress"
then
    echo "Incorrect invocation: target address not specified." >/dev/stderr
    exit 3
fi

if test "$timeout"
then timeout="-t $timeout"
fi

if test "$snmpcommunity"
then snmpcommunity="-c $snmpcommunity"
else snmpcommunity="-c public"
fi

message=`snmpget -Oqv -v1 $snmpcommunity $timeout $hostaddress SNMPv2-MIB::sysDescr.0`
status=$?

if test $status -ne 0
then status=2
fi

case $status in
    (0) status_description=OK ;;
    (1) status_description=WARNING ;;
    (2) status_description=CRITICAL ;;
    (3) status_description=UNKNOWN ;;
esac

echo "$message"

if test ! $status
then exit 3
else exit $status
fi

