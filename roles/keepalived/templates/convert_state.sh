#!/bin/bash
#

usage() {
    echo "./`basename $0` {master|backup}"
    exit 1
}

if [ $# -eq 0 ]; then
    usage
fi

if [[ "$1" = "master" ]]; then
    [ -f /etc/keepalived/down ] && rm -f /etc/keepalived/down
elif [[ "$1" = "backup" ]]; then
    [ ! -f /etc/keepalived/down ] && touch /etc/keepalived/down
else
    usage
fi
sleep 1



