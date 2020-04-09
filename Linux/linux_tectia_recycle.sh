#!/bin/sh
# Script to recycle Tectia via cron job
#
# No user interaction.
#
#
# Author
# ----------- ---------  ----------------------------------------------
# Daniel Zhelev  04192012  Changed the way we get the PPID
# Daniel Zhelev  04182012  Script creation

tecstop() {
## Stopping tectia and killing any remaining processes
GTECPID=`ps -e -o pid,args | grep -v grep | grep "ssh-server-g3" | awk '{print $1}'`
TECPID=$GTECPID
/etc/init.d/ssh-server-g3 stop
sleep 10
  if [ `ps -e -o pid,ppid | grep -c $TECPID` -gt 0 ]
   then
    for PID in `ps -e -o pid,ppid | grep $TECPID | awk '{print $1}'`
     do kill -9 $PID >/dev/null 2>&1
    done
  fi

## killing ssh-broker-cli which hanges and a user cannot connect to tectia
  if [ `ps -e -o pid,args | grep -v grep | grep -c "ssh-broker-cli"` -gt 0 ]
   then
    kill -9 `ps -e -o pid,args | grep -v grep | grep "ssh-broker-cli" | awk '{print $1}'` >/dev/null 2>&1
  fi
}

tecstop
/etc/init.d/ssh-server-g3 start >/dev/null 2>&1
