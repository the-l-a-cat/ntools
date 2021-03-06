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
    echo "Usage: agava_check_snmp_pair -H HOSTNAME -n EXTNUMBER [-C COMMUNITY] [-t TIMEOUT]"
    exit 3
fi

while getopts H:C:t:n: VARNAME
do
    case $VARNAME in
        (H) hostaddress="$OPTARG" ;;
        (C) snmpcommunity="$OPTARG" ;;
        (t) timeout="$OPTARG" ;; 
        (n) extnumber="$OPTARG" ;;
    esac
done

if test ! "$hostaddress"
then
    echo "Incorrect invocation: target address not specified." >/dev/stderr
    exit 3
fi

if test ! "$extnumber"
then
    echo "Incorrect invocation: extension ID not specified." >/dev/stderr
    exit 3
fi

if test "$timeout"
then timeout="-t $timeout"
fi

if test "$snmpcommunity"
then snmpcommunity="-c $snmpcommunity"
else snmpcommunity="-c public"
fi

status=`snmpget -Oqv -v1 $snmpcommunity $timeout $hostaddress UCD-SNMP-MIB::extResult.$extnumber`
message=`snmpget -Oqv -v1 $snmpcommunity $timeout $hostaddress UCD-SNMP-MIB::extOutput.$extnumber`

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

