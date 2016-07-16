#!/bin/bash
#

if pkill -0 nginx>/dev/null ; then
    [ `curl -sL -w %{http_code} http://localhost -o /dev/null` -eq 200 ] && exit 0
else
    service nginx start
fi
exit $?
