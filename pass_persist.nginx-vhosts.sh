#!/bin/sh

# Manufactured by kin @ agava Thu 27 Mar 2014

# Purpose: Reliably extract IP HOST pairs from nginx configuration, if such is present.
# Advancement: The script presents extracted pairs to net-snmpd pass-persist directive.

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

update_nginx_vhosts_tab ()
{
    if
        test -f $nginx_conf
    then
        # Through this logic we avoid
        # unnecessary invocation of 
        # expensive vhosts list rebuild
        # when the source file does not
        # appear to have changed.
        nginx_conf_md5_new="`$my_md5 $nginx_conf`"
        if
            test "$nginx_conf_md5" != "$nginx_conf_md5_new"
        then
            echo "`date +%s` nginx.conf hash has changed; rebuilding table." >> $log/$my_name.log
            nginx_conf_md5="$nginx_conf_md5_new"

            awk \
                -v default_ip=$default_ip \
                "$awk_command"  \
                $path_root/$path_nginx_conf \
                > $spool/$my_name.tab

            echo "`date +%s` Written `cat $spool/$my_name.tab | wc -l` entries in the table." >> $log/$my_name.log
        else
            : # Do nothing, config did not change.
        fi
    else
        exit 1
    fi 
}

reply_snmp_oid_request ()
{
    # $1 is the column, $2 is the row, $3 is the total row count, $4 is the head path.
    column=$1
    row=$2
    count=$3
    head=$4

    case $column in
        (0) # This should eventually return some status, yet to define.
            echo $head.$column
            echo "integer"
            echo "0"
            ;;
        (1) # This returns number of rows present.
            echo $head.$column
            echo "integer"
            echo $count
            ;;
        (*00)
            if
                test $row -gt $count
            then
                echo "NONE"
            else 
                echo $head.$column.$row 
                eval echo \$c${column}_type
                eval echo \$c${column}_${row}
            fi
            ;;
        (*)
            echo "NONE"
            ;;
    esac
}

case `uname -s` in
    (Linux)
        path_root=/
        path_nginx_conf=/etc/nginx/nginx.conf
        operating_system=Linux
        my_md5=md5sum
        ;;
    (FreeBSD)
        path_root=`get_first_jail_root`
        path_nginx_conf=/usr/local/etc/nginx/nginx.conf
        operating_system=FreeBSD
        my_md5=md5
        ;;
    (*)
        exit 1
        ;;
esac

spool=/var/spool/snmp-agava
log=/var/log/snmp-agava 
mkdir -p $spool $log

my_name=`basename $0`

oid_head=.1.3.1.3.3.7.1

c100_type=ipaddress
c200_type=string

default_ip=`get_default_ip`

nginx_conf=$path_root/$path_nginx_conf

vhosts_rebuild_interval=60 # Seconds.

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


# Main loop.
while read snmpd_command
do
    if
        test ! -f $nginx_conf
    then
        case $snmpd_command in

            (PING|ping)
                echo PONG
                ;;
        
            (GET|get)
                read oid
                echo $oid
                echo String
                echo - # I cannot echo an empty string since
                       # Python netsnmp bindings take it for None
                       # which is indistinguishable from an SNMP error.
                ;;

            (GETNEXT|getnext)
                read oid
                echo NONE
                ;;

            ("")
                # Empty string signals snmpd termination.
                exit 0
                ;; 

            (*)
                : # Ignore.
                ;; 
        esac
    else

        # Mechanics that update our tiny database.
        current_timestamp=`date +%s`
        if test $current_timestamp -gt $(( $last_update_timestamp + $vhosts_rebuild_interval ))
        then
            last_update_timestamp=$current_timestamp 
            update_nginx_vhosts_tab
            
            i=0
            while read IP HOST
            do
                i=$(($i+1))
                eval c100_$i=$IP
                eval c200_$i=$HOST
            done < $spool/$my_name.tab 
            vhosts_count=$i
        fi 

        case $snmpd_command in

            (PING|ping)
                echo PONG
                ;;

            (GET|get)
                read oid
                oid_tail=${oid#$oid_head.}
                oid_column=${oid_tail%.*}
                oid_row=${oid_tail#*.} 

                reply_snmp_oid_request $oid_column $oid_row $vhosts_count $oid_head

                ;;

            (GETNEXT|getnext)
                read oid
                oid_tail=${oid#$oid_head.}
                oid_column=${oid_tail%.*}
                oid_row=${oid_tail#*.}

                
                # Increment.
                case $oid_column in
                    (0) 
                        oid_column=1
                        oid_row=""
                        ;;
                    (1)
                        oid_column=100
                        oid_row=1
                        ;;
                    (100)
                        if
                            test $oid_row -eq $vhosts_count
                        then
                            oid_column=200
                            oid_row=1
                        else 
                            oid_row=$(($oid_row+1))
                        fi
                        ;;
                    (200)
                        oid_row=$(($oid_row+1))
                        ;;
                    (*) 
                        oid_column=314159 # Nonexistent.
                        oid_row=14142 # Nonexistent.
                        ;;
                esac

                reply_snmp_oid_request $oid_column $oid_row $vhosts_count $oid_head

                ;;

            ("")
                # Empty string signals snmpd termination.
                exit 0
                ;; 

            (*)
                : # Ignore.
                ;;

        esac
    fi
done


