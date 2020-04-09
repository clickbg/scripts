#!/usr/local/bin/bash
# Author: Daniel Zhelev @ https://zhelev.biz
MAIL="root"
MIRRORS="2"


#### DO NOT EDIT BELOW
MIRROR=$(/sbin/gmirror status | grep "COMPLETE" | wc -l)

if [ $MIRROR != $MIRRORS  ]; then
echo -e "`/sbin/gmirror list`\n." | mail -s "Mirroring server: RAID1 Failure" -E $MAIL
exit 1;
else 
exit 0;
fi
