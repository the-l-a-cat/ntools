#!/bin/sh

my_valid_name_characters='[a-zA-Z0-1]'

f_validate ()
{
    # echo entering f_validate >/dev/stderr
    if test -z "$1"
    then return 1
    else
        VAR="$1"
        if
            # ! test "$VAR" = `printf %q "$VAR"` # Not portable nuff.
            test -n "`
                while
                    test "$VAR" != "${VAR#$my_valid_name_characters}"
                do
                    VAR="${VAR#$my_valid_name_characters}"
                done && echo $VAR `"

        then return 1
        fi
    fi
    return 0
}


if ! f_validate "$1"
then
    exit 1
fi

SERVICE=$1

if
    # FreeBSD 5.
    test -x /usr/local/etc/rc.d/$SERVICE.sh
then
    /usr/local/etc/rc.d/$SERVICE.sh restart

elif
    # Late FreeBSD.
    test -x /usr/local/etc/rc.d/$SERVICE
then
    /usr/local/etc/rc.d/$SERVICE restart

elif
    # Maybe Linux.
    test -x /etc/rc.d/$SERVICE
then
    /etc/rc.d/$SERVICE restart

else
    # Generic modern OS.
    service $SERVICE restart

fi
