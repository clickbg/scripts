#!/usr/bin/env bash
# Monitor Linux mdadm devices
# Author: Daniel Zhelev @ https://zhelev.biz
###################
EXIT=0
LINES="=============================================="
DEVICE="$1"

if [ -z "$DEVICE" ]
then
 echo "Usage: $(basename "$0") md device"
 exit 1
fi

  RAID_DEV=/dev/md/$DEVICE
  NUMBER_OF_DEVICES=$(mdadm --detail $RAID_DEV | grep "Raid Devices" | cut -d ":" -f2 | tr -d ' ')
  NUMBER_OF_WORKING_DEVICES=$(mdadm --detail $RAID_DEV | grep "Working Devices" | cut -d ":" -f2 | tr -d ' ')
  NUMBER_OF_FAILED_DEVICES=$(mdadm --detail $RAID_DEV | grep "Failed Devices" | cut -d ":" -f2 | tr -d ' ')
  ARRAY_STATE=$(mdadm --detail $RAID_DEV | grep "State :" | cut -d ":" -f2 | tr -d ' ')


  case "$ARRAY_STATE" in
    active*|clean*)
    ;;
    *)
     EXIT=1
    ;;
    esac


  if [ "$NUMBER_OF_FAILED_DEVICES" -ne 0 ]
   then
    EXIT=1
  fi

   echo $LINES
   echo "Array name: $RAID_DEV"
   echo "Array state: $ARRAY_STATE"
   echo "Devices: $NUMBER_OF_WORKING_DEVICES/$NUMBER_OF_DEVICES"
   [ "$NUMBER_OF_FAILED_DEVICES" -ne 0 ] && echo "Failed devices: $NUMBER_OF_FAILED_DEVICES"
   echo $LINES

exit $EXIT
