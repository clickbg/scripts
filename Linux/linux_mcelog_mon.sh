#!/usr/bin/env bash
# Author: Daniel Zhelev @ https://zhelev.biz
###################

HWLOG="/var/log/mcelog"
LOG_PREFIX="$(date +%Y-%m-%d\ %H:%M:%S) $HOSTNAME"
MCELOG=$(which mcelog)

if [ -f $MCELOG ]; then

        $MCELOG --ignorenodev --filter --logfile $HWLOG
else
        echo "$LOG_PREFIX CRITICAL: Error mcelog not found"
        exit 1
fi

if [ $(grep -c "hardware error" $HWLOG) -gt 0 ]; then
        echo -e "$LOG_PREFIX CRITICAL: $(grep -c "hardware error" $HWLOG) Hardware Errors Found $(hostname) @ $(date) \n \n $(tail $HWLOG) "
        $(which logger) HW status: CRITICAL - inspect $HWLOG
        exit 1
else

        echo "$LOG_PREFIX INFO: HW status: OK"
        exit 0
fi
