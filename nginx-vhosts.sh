#!/bin/sh

# Manufactured by kin @ agava Thu 27 Mar 2014

# Purpose: Reliably extract IP HOST pairs from nginx configuration, if such is present.

get_first_jail_root ()
{
    cat /etc/rc.conf |
    grep '^jail_.*_rootdir' |
    head -n1 |
    cut -d= -f2 |
    tr -d \"
}

get_default_ip_linux ()
{
    dig +short A `uname -n` |
    head -n1
    # I know it's unreliable.
}

get_default_ip_freebsd ()
{
    less /etc/rc.conf |
    grep jail_.\*_ip |
    cut -d\" -f 2 |
    cut -d\" -f 1 |
    cut -d\, -f 1 |
    head -n1
}

get_default_ip ()
{
    case $operating_system in
        (Linux)
            get_default_ip_linux
            ;;
        (FreeBSD)
            get_default_ip_freebsd
            ;;
        (*)
            exit 1
            ;;
    esac
}




case `uname -s` in
    (Linux)
        path_root=/
        path_nginx_conf=/etc/nginx/nginx.conf
        operating_system=Linux
        ;;
    (FreeBSD)
        path_root=`get_first_jail_root`
        path_nginx_conf=/usr/local/etc/nginx/nginx.conf
        operating_system=FreeBSD
        ;;
    (*)
        exit 1
        ;;
esac

default_ip=`get_default_ip`

nginx_conf=$path_root/$path_nginx_conf

awk_command=' /(listen|server_name[ \t])/ {
    if ($1 ~ /listen/) 
    {
        split ( $2, LISTEN, /[;:]/ )
        IP=LISTEN[1]
    } 
    
    if ($1 ~ /server_name/ )
    {
        split ( $2, SERVER_NAME, ";" ) 
        NAME=SERVER_NAME[1] 
    } 
    
    if ( NAME && IP )
    {
        if (IP == 80) IP=default_ip

        if ( NAME !~ /localhost/ && 
            IP !~ /^127\./ ) print IP "\t" NAME 
        IP="" 
        NAME="" 
} } ' 
# Feel da power!

if
    test -f $nginx_conf || test -h $nginx_conf
then
    awk \
        -v default_ip=$default_ip \
        "$awk_command"  \
        $path_root/$path_nginx_conf
    exit 0
else
    exit 1
fi 

