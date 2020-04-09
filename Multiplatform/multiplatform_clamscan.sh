#!/usr/local/bin/bash
# Author: Daniel Zhelev @ https://zhelev.biz

# email subject
SUBJECT="VIRUS DETECTED ON `hostname`!!!"
# Email To ?
EMAIL="root"
# Log location
LOG=/var/log/clamav/scan.log
# What to scan
SCAN=$1


# Die func
die()
{
        echo "$@" >&2
        exit 1
}


# Testing
[[ -z $SCAN ]] && die "./clamscan.sh DIRECTORY_TO_SCAN"

# Check scan and report
check_scan () {

    # Check the last set of results. If there are any "Infected" counts that aren't zero, we have a problem.
    if [ `tail -n 12 ${LOG}  | grep Infected | grep -v 0 | wc -l` != 0 ]
    then
        EMAILMESSAGE=`mktemp /tmp/virus-alert.XXXXX`
        echo "To: ${EMAIL}" >>  ${EMAILMESSAGE}
        echo "Subject: ${SUBJECT}" >>  ${EMAILMESSAGE}
        echo "Importance: High" >> ${EMAILMESSAGE}
        echo "X-Priority: 1" >> ${EMAILMESSAGE}
        echo "`tail -n 50 ${LOG}`" >> ${EMAILMESSAGE}
        /usr/sbin/sendmail -t < ${EMAILMESSAGE}
        rm $EMAILMESSAGE
        cp -p $LOG $LOG.INFECTED.`date +%d%m%Y`
    fi

cat /dev/null > $LOG
}

find $SCAN -not -wholename '/sys/*' -and -not -wholename '/proc/*' -and -not -wholename '/srv/webdata/mirrors/*' -and -not -wholename '/srv/webdata/cloud/*' -mmin -61 -type f -print0 | \
xargs -0 -r clamscan --exclude-dir=/proc/ --exclude-dir=/sys/ --exclude-dir=/srv/webdata/mirrors --exclude-dir=/srv/webdata/cloud/ --quiet --infected --log=${LOG} --remove=yes
check_scan

find $SCAN -not -wholename '/sys/*' -and -not -wholename '/proc/*' -and -not -wholename '/srv/webdata/mirrors/*' -and -not -wholename '/srv/webdata/cloud/*' -cmin -61 -type f -print0 | \
xargs -0 -r clamscan --exclude-dir=/proc/ --exclude-dir=/sys/ --exclude-dir=/srv/webdata/mirrors --exclude-dir=/srv/webdata/cloud/ --quiet --infected --log=${LOG} --remove=yes
check_scan
