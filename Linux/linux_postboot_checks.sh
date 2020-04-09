#!/usr/bin/env bash
# Useful script that we run @reboot
# Author: Daniel Zhelev @ https://zhelev.biz

################################ Begin config
EMAIL="root"
DELAY="480"
POST_BOOT_LOG="/var/log/postboot.log"
ERROR_PATTERN="crit|error|warn|fail|unable"
IGNORE_PATTERN="PNP0A03"
################################ End config


################################ Begin script vars
LINES="============================================================================================================"
EXIT=0

# Set secure umask
umask 077

################################ End script vars


################################

report_state()
{
echo $LINES
echo "Current state of system $(hostname -f):"
echo $LINES
monit status $(hostname -f) | grep -v "Monit"
echo
echo $LINES
echo
}


check_services()
{
echo $LINES
echo "Current state of all services running on system $(hostname -f):"
echo $LINES
echo
monit report
echo
SERVICES_DOWN=$(monit report down)
if [[ $SERVICES_DOWN -ne 0 ]]
 then
  echo
  echo "Services currently DOWN: $SERVICES_DOWN"
  echo
  monit summary -B | egrep -v "Monit|OK"
  echo
  let "EXIT++"
fi

SERVICES_UNMONITORED=$(monit report unmonitored)
if [[ $SERVICES_UNMONITORED -ne 0 ]]
 then
  echo
  echo "Services currently UNMONITORED: $SERVICES_UNMONITORED"
  echo
  monit summary -B | egrep -v "Monit|OK"
  echo
  let "EXIT++"
fi

echo $LINES
echo
}


check_logs()
{
echo $LINES
echo "Searching common logs for errors:"
echo $LINES
echo
echo "SEARCH PATTERN: $ERROR_PATTERN"
echo "IGNORE PATTERN: $IGNORE_PATTERN"
echo

LOG_FILES_LIST=$(find /var/log \( -name "messages*" -o -name "syslog*" -o -name "boot*" -o -name "dmesg*" \) -type f -mtime -1)
if [[ -z $LOG_FILES_LIST ]]
 then
  echo "No recent logs found"
  echo
  let "EXIT++"
  return 1
fi

echo
echo "Searching in:"
echo "$LOG_FILES_LIST"
echo
OUTPUT=$(egrep -i $ERROR_PATTERN $LOG_FILES_LIST | egrep -v $IGNORE_PATTERN)
if [[ ! -z $OUTPUT ]]
 then
  echo
  echo "$OUTPUT"
  echo
  let "EXIT++"
 else
  echo
  echo "All good, no logs matched our pattern."
  echo
fi

echo $LINES
echo
}


check_users_prior_reboot()
{
echo $LINES
echo "Users logged in prior the reboot:"
echo $LINES
echo
REBOOT_DATE=$(last | grep reboot | head -1 | awk '{print $6, $7}')
last | grep "$REBOOT_DATE" | grep -A 100 "reboot"
echo

echo $LINES
echo
}


main()
{
report_state
check_services
check_logs
check_users_prior_reboot
}

sleep $DELAY
main > $POST_BOOT_LOG
if [[ $EXIT -ne 0 ]]
 then
  SUBJECT="[ERROR] System $(hostname -f) rebooted and $(basename $0) detected problems"
 else
  SUBJECT="[INFO] System $(hostname -f) rebooted, system is operating normally now."
fi

cat $POST_BOOT_LOG | mail -s "$SUBJECT" $EMAIL
exit $EXIT
