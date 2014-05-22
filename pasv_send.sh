#!/bin/sh

# ---------------------------------------------------------------------------- #
#                                                                              #
#       This script's only purpose is to write certain lines to                #
#       the Nagios command file. The template line is a passive                #
#       check submission.                                                      #
#                                                                              #
#       The script is supposed to be accompanied with a server                 #
#       counterpart that's being used as a CGI application.                    #
#                                                                              #
# ---------------------------------------------------------------------------- #

# I expect arguments to go as follows:
#   1. "service"
#   2. $host_name
#   3. $service_description
#   4. $return_code
#   5. $plugin_output

f_encode ()
{
    echo "$1" | b64encode msg |
        grep -vxF -e 'begin-base64 644 msg' -e '====' | tr -d '\n' 
}

f_submit ()
{
    msg_description_encoded=$(f_encode "$msg_description")

    fetch -q -a -o - \
        "https://$login:$password@$host/nagios/cgi-bin/pasv_subm.cgi?\
service:$msg_host:$msg_service:$msg_state:$msg_description_encoded" \
        > /dev/null 
}

f_log ()
{
    msg_description_encoded=$(f_encode "$msg_description")
    printf "%d\t%s\t%s\t%s\t%s\n" \
        $timestamp \
        "$msg_host" \
        "$msg_service" \
        "$msg_state" \
        "$msg_description_encoded" >> "$log_file"
}

(

login='mechanic'
password='gRshfBWucWIrx21r'
host='monitor.col.agava.net' 
log_file="/var/log/pasv_send.log"
timestamp=$(date +%s)

msg_host="$(cat /etc/agava-server_id | tr -d '\n')"
msg_service="unknown"
msg_state="3"
msg_description="Passive check <$msg_host>: default passive check."

if false
then :

elif
    test -n "$SMARTD_DEVICE"
    # SmartD would have this variable set if calling this script via its -M
    # facility.  
then
    msg_service="S.M.A.R.T."
    if
        test "$SMARTD_FAILTYPE" = "EmailTest"
    then
        msg_state="0"
        msg_description="SmartD<$msg_host>: restart event registered."
    else
        sleep 2 # To ensure these emails come
                 # rather later than OK state reports.
        msg_state="2"
        msg_description="$msg_service<$msg_host>: device $SMARTD_DEVICESTRING event $SMARTD_FAILTYPE time $SMART_TFIRST"
    fi 
    f_submit &
    f_log 
elif
    test "$1" = "--reset"
then
    msg_service="S.M.A.R.T."
    msg_state="0"
    msg_description="$msg_service<$msg_host>: reset event invoked."
    f_submit &
    f_log 
elif
    test "$1" = "--reset-outdated" &&
    test -n "$2"
then
    last_timestamp=$(grep "$2" "$log_file" | tail -n1 | cut -f 1)
    if
        test -n "$last_timestamp" &&
        test $last_timestamp -lt $(( $timestamp - 86400 ))
    then
        msg_service="$2"
        msg_state="0"
        msg_description="$msg_service<$msg_host>: outdated event reset."

        f_submit &
        f_log
    fi


# Add more logic as you see fit.

fi

) &
