#!/bin/sh

# ---------------------------------------------------------------------------- #
#                                                                              #
#       This script's only purpose is to write certain lines to                #
#       the Nagios command file. The template line is a passive                #
#       check submission.                                                      #
#                                                                              #
# ---------------------------------------------------------------------------- #

# I expect arguments to go as follows:
#   1. "service"
#   2. $host_name
#   3. $service_description
#   4. $return_code
#   5. $plugin_output

mask_nagios_host_name='[a-zA-Z0-9.-_ ]'
mask_nagios_service_description='[a-zA-Z0-9.-_ ]'
mask_nagios_plugin_output='[a-zA-Z0-9.-_ ]' 
nagios_command_file='/usr/local/nagios/var/rw/nagios.cmd'

f_validate ()
{ 
    if test -z "$myValChar"
    then myValChar='[a-zA-Z0-9_]'
    fi

    if test -z "$1"
    then return 1 # Empty argument disallow.
    # then return 0 # Empty argument permitted.
    else
        VAR="$1"
        if
            # ! test "$VAR" = `printf %q "$VAR"` # Not portable nuff.
            test -n "`
                while
                    test "$VAR" != "${VAR#$myValChar}"
                do
                    VAR="${VAR#$myValChar}"
                done && echo $VAR `"

        then return 1
        fi
    fi
    return 0
}

f_submit_service_check ()
{ 
    if test -w $nagios_command_file
    then
        printf "[%d] PROCESS_SERVICE_CHECK_RESULT;%s;%s;%s;%s" \
            $(date +%s) "$1" "$2" "$3" "$4"
    else
        exit 1 
    fi 
}

echo

IFS=':'
set -- $QUERY_STRING

if false
then :

elif test "$1" = "service"
then
    if
        myValChar=$mask_nagios_host_name               f_validate "$2" &&
        myValChar=$mask_nagios_service_description     f_validate "$3" &&
        myValChar=$mask_nagios_return_code             f_validate "$4" &&
        myValChar=$mask_nagios_plugin_output           f_validate "$5"
    then
        f_submit_service_check "$2" "$3" "$4" "$5"
    else
        exit 1
    fi 
else
    exit 1
fi


