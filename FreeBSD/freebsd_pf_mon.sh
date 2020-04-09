#!/usr/local/bin/bash
# Author: Daniel Zhelev @ https://zhelev.biz

# Where to save the current rules
PF_FILE="/var/log/pf.state"

# Should we override the recorded PF_FILE
# every time a change is detected(this will prevent dublicate messages
OVERRIDE="yes"

# Path to iptables - leave it so if you are not sure
PFCTL=/sbin/pfctl

### CONFIGURATION ENDS HERE

check()
{
cmp -s <($PFCTL -sr) $PF_FILE
if [ $? -ne 0 ]
 then
    echo "PF change detected"
    echo "Diff of the pf rules"
    echo "Left: Current rules"
    echo "Right: Saved rules"
    diff -l --suppress-common-lines --side-by-side -y --width=200 <($PFCTL -sr) $PF_FILE
     if [ $OVERRIDE == "yes" ]
      then
      $PFCTL -sr > $PF_FILE
      chmod 600 $PF_FILE
     fi
    exit 1
 else
   echo "No changes in the PF rules detected."
   exit 0
fi
}


if [[ -s $PF_FILE ]]
 then
   check
 else
   $PFCTL -sr > $PF_FILE
   chmod 600 $PF_FILE
   check
fi

