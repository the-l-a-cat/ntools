#!/bin/sh

# ------------------------------------------------------------------------------
# kin @ agava Sat 12 Apr 2014
# ------------------------------------------------------------------------------
# Purpose: Check all sites listed in snmp branch .1.3.1.3.3.7.1 which I designed
# and run as a server-side script with pass netsnmp directive.
# ------------------------------------------------------------------------------

mibPrefix='.1.3.1.3.3.7.1' 
snmpTimeout=2
httpTimeout=10
check_http=check_http-1.5-patched
timeout=$snmpTimeout
maxHostCount=12
levelWarning=0
levelCritical=0
USER1="/usr/share/nagios/libexec/" # The same meaning
                                   # as in any ordinary Nagios installation.
check_http="$USER1/$check_http"


if test $# -eq 0
then
    echo "Usage: agava_check_http.sh
    -H HOSTNAME
    [-w WARNING]
    [-c CRITICAL]
    [-C COMMUNITY]
    [-m MAXHOSTS]"
    exit 3
fi

while getopts H:C:m:c:w:t: VARNAME
do
    case $VARNAME in
        (H) hostaddress="$OPTARG" ;;
        (t) timeout="$OPTARG" ;;
        (w) levelWarning="$OPTARG" ;;
        (c) levelCritical="$OPTARG" ;;
        (C) snmpcommunity="$OPTARG" ;;
        (m) maxHostCount="$OPTARG" ;;
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

stateOK=0
stateWarning=0
stateCritical=0
stateUnknown=0

hostCount=`snmpget -Oqv -v1 $snmpcommunity $timeout $hostaddress $mibPrefix.1` 

if test $? -ne 0
then
    message="Unknown: SNMP failure."
    status=3

elif test $hostCount -eq 0
then
    message="Warning: zero site count."
    status=1
elif test ! $hostCount
then
    message="Unknown: Host count undefined. Are you sure there's NginX on the target?"
    status=3
else

    if test $hostCount -gt $maxHostCount
    then
        realHostCount=$hostCount
        hostCount=$maxHostCount
    fi # We cannot afford more.

    for index in `seq $hostCount`
    do
        errorCount=0
        siteAddress=`snmpget -Oqv -v1 $snmpcommunity $timeout $hostaddress $mibPrefix.100.$index`
        errorCount=$(( $errorCount + $? ))
        siteName=`snmpget -Oqv -v1 $snmpcommunity $timeout $hostaddress $mibPrefix.200.$index`
        siteName=${siteName%\"}
        siteName=${siteName#\"}
        errorCount=$(( $errorCount + $? ))
        if test $errorCount -gt 0
        then
            siteResponse="Unable to fetch host/address via SNMP."
            siteStatus=3
        else

            siteResponse=`$check_http -I $siteAddress -H $siteName -t $httpTimeout`
            siteStatus=$?

            case $siteStatus in

                (0) stateOK=$(($stateOK + 1))
                    ;;

                (1) stateWarning=$(($stateWarning + 1)) 
                    ;;

                (2) stateCritical=$(($stateCritical + 1))
                    ;;

                (3) stateUnknown=$(($stateUnknown + 1))
                    ;;

            esac 
        fi

        message="$message"'\n'"Address $siteAddress Host $siteName :: ""${siteResponse%|*}"
    done

    if # All good.
        test $(( ( $stateWarning + $stateCritical + $stateUnknown ) * 100 / $hostCount )) -le $levelWarning
    then
        if test ! $realHostCount
        then tagline="OK: $hostCount"
        else tagline="OK: $hostCount ($realHostCount)"
        fi
        status=0

    elif
        test $(( ( $stateCritical + $stateUnknown ) * 100 / $hostCount )) -le $levelCritical
    then # Warning state.
        if test ! $realHostCount
        then tagline="Warning: $hostCount = $stateOK ok + $stateWarning warning."
        else tagline="Warning: $hostCount ($realHostCount) = $stateOK ok + $stateWarning warning."
        fi
        status=1

    elif
        test $(( $stateUnknown )) -eq 0
    then # Critical state.
        if test ! $realHostCount
        then tagline="Critical: $hostCount = $stateOK ok + $stateWarning warning + $stateCritical critical."
        else tagline="Critical: $hostCount ($realHostCount) = $stateOK ok + $stateWarning warning + $stateCritical critical."
        fi
        status=2

    else # Not sure if good or not.
        if test ! $realHostCount
        then tagline="Unknown: $hostCount = $stateOK ok + $stateWarning warning + $stateCritical critical + $stateUnknown unknown."
        else tagline="Unknown: $hostCount ($realHostCount) = $stateOK ok + $stateWarning warning + $stateCritical critical + $stateUnknown unknown."
        fi

    fi
    message="$tagline""\n""$message"

fi

echo -e "$message"

if test ! $status
then exit 3
else exit $status
fi


