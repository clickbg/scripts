#!/bin/bash
# A script for monitoring the status of linux bonding interfaces
# Author: Daniel Zhelev @ https://zhelev.biz
INTERFACE=$1
LINES="=============================================="

if [ -z "$INTERFACE" ]
then
 echo "Usage: $(basename "$0") INTERFACE"
 exit 1
fi

if [ ! -e /proc/net/bonding/$INTERFACE ]
then
 echo "Bonding interface $INTERFACE doesn't exist"
 exit 1
else
 LINKS_DOWN_COUNT=$(grep -cw down /proc/net/bonding/$INTERFACE)
 LINKS_UP_COUNT=$(grep -cw up /proc/net/bonding/$INTERFACE)
 NUMBER_OF_SLAVES=$(grep -cw "Slave Interface" /proc/net/bonding/$INTERFACE)
fi

if [ $LINKS_DOWN_COUNT -gt 0 ]
 then
  echo
  echo $LINES
  echo "ERROR: Link DOWN detected, please check the cables or configuration"
  echo $LINES
  echo
  echo $LINES
  echo "Link status for $INTERFACE: $LINKS_DOWN_COUNT/$NUMBER_OF_SLAVES DOWN"
  echo $LINES
  echo
  echo $LINES
  echo "Details:"
  echo $LINES
  cat /proc/net/bonding/$INTERFACE | egrep "Bonding Mode|Slave Interface|MII Status|Speed|Duplex|Link Failure Count"
  echo $LINES
  exit 1
elif [ $NUMBER_OF_SLAVES -lt 2 ]
 then
  echo
  echo $LINES
  echo "ERROR: Inadequate number of slaves detected, please check the cables or configuration"
  echo $LINES
  echo
  echo $LINES
  echo "Slaves count (minimum 2 expected): $NUMBER_OF_SLAVES"
  echo $LINES
  echo
  echo $LINES
  echo "Details:"
  echo $LINES
  cat /proc/net/bonding/$INTERFACE | egrep "Bonding Mode|Slave Interface|MII Status|Speed|Duplex|Link Failure Count"
  echo $LINES
  exit 1
else
  echo
  echo $LINES
  echo "Slaves status for $INTERFACE: $(expr $LINKS_UP_COUNT - 1)/$NUMBER_OF_SLAVES UP"
  echo $LINES
  echo
  echo $LINES
  echo "Details:"
  echo $LINES
  cat /proc/net/bonding/$INTERFACE | egrep "Bonding Mode|Slave Interface|MII Status|Speed|Duplex|Link Failure Count"
  echo $LINES
  exit 0
fi
