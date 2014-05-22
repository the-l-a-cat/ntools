#!/bin/sh 

# kin @ agava
# Fri 17 Jan 2014

# Rewrite Thu 22 May 2014
# Now it's not a stream filter anymore, but rather a nagios check.

# Project S1
# Program check_dns
# Purpose: Check if a DNS server is an amplifying one.

iterate=4 
msg_size_limit=256

requests=( "google.com" "ANY isc.org" "+bufsize=1024 google.com" "+bufsize=1024 ANY isc.org" "+bufsize=65535 ANY isc.org" )

# read -r target
target="$1"
temp=$(mktemp -d)

for request in "${requests[@]}"
do
    i=$((i+1))
    dig +ignore +time=1 +tries=$iterate @$target $request > $temp/$i &
done
wait

flag_dig_connect=0
for file in $temp/*
do
    if
        grep -qxF ';; connection timed out; no servers could be reached' $file
    then
        : # Do nothing
    else
        flag_dig_connect=1
        break
    fi
done

if 
    [ $flag_dig_connect -ne 1 ] 
then 
    rm -rf $temp/*
    rmdir $temp
    echo "Ok: $target -- no response."
    exit 0
    # echo "Unknown: $target -- no response."
    # exit 3
fi

cat $temp/* | grep '^;; MSG SIZE  rcvd:' | grep -o '[0-9]\+' > $temp/grep_msg

while read -r msg_size
do
    if
        [ $msg_size -gt $msg_size_limit ]
    then
        flag=True
        export msg_size
        break
    fi
done < $temp/grep_msg

rm -rf $temp/*
rmdir $temp

if
    [ x$flag = "xTrue" ]
then
    # echo -e $target
    echo "Amplifier: $target -- long response. (Response $msg_size, Limit $msg_size_limit.)" 
    exit 2
else
    echo "Good: $target -- short response. (Response $msg_size, Limit $msg_size_limit.)"
fi

