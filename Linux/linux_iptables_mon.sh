#!/usr/bin/env bash
# Author: Daniel Zhelev @ https://zhelev.biz
###################

# Where to save the current rules
IPT_FILE="/var/log/iptables.state"

# Should we override the recorded IPT_FILE
# every time a change is detected(this will prevent dublicate messages
OVERRIDE="yes"

# Path to iptables - leave it so if you are not sure
IPTABLES=/sbin/iptables

### CONFIGURATION ENDS HERE

check()
{
cmp -s <($IPTABLES -L -n) $IPT_FILE
if [ $? -ne 0 ]
 then
   echo "Iptables change detected"
   echo "Diff of the iptables rules"
   echo "Left: Current rules"
   echo "Right: Saved rules"
   diff -l --side-by-side --suppress-common-lines -y <($IPTABLES -L -n) $IPT_FILE
     if [ $OVERRIDE == "yes" ]
      then
      $IPTABLES -L -n > $IPT_FILE
      chmod 600 $IPT_FILE
     fi
   exit 1
 else
   echo "No changes detected in iptables rules."
   exit 0
fi
}


if [[ -s $IPT_FILE ]]
 then
   check
 else
   $IPTABLES -L -n > $IPT_FILE
   chmod 600 $IPT_FILE
   check
fi
