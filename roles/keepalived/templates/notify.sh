#!/bin/bash
#

declare -a vips=({{vip1}} {{vip2}})
from={{ from }}
to={{ to }}
user={{ user }}
pwd={{ pwd }}

notify() {
    #$1: A string indicating whether it's a "GROUP" or an "INSTANCE"
    #$2: The name of said group or instance
    #$3: The state it's transitioning to ("MASTER", "BACKUP" or "FAULT")
    #$4: The priority value
    if [ "$2" = "VI_1" ]; then
        vip=${vips[0]}
    elif [ "$2" = "VI_2" ]; then
        vip=${vips[1]}
    fi
    msg="`date +%FT%H:%M:%S` $1 \"$2\" VIP \"${vip}\" have moved, HOST `hostname` turn to $3 state with the priority $4."
    #echo ${msg} | mailx -s "Keepalived state changed" -r $from -S smtp-auth-user=$user -S smtp-auth-password=$pwd $to
    echo ${msg} >> /tmp/keepalived.log
}

case $1 in
    master)
        exit 0
    ;;
    backup)
        exit 0
    ;;
    fault)
        exit 0
    ;;
    *)
        notify $1 $2 $3 $4
        exit 0
    ;;
esac
