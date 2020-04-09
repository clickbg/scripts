#!/usr/bin/ksh
# Author: Daniel Zhelev @ https://zhelev.biz
# SAN checker script
# Checks if all SAN disks have 2 or more paths
# Execution: Called by operator

EXITCODE=0

power_check() {
EMC_DEVS="$(/opt/EMCpower/bin/emcpadm getusedpseudos | grep "emc" | awk '{print $1}')"
echo "Starting EMC PowerPath checks"
echo
for device in $EMC_DEVS
 do 
  /etc/powermt display dev=$device | grep -i dead > /dev/null
   if [ $? -eq 0 ]
    then 
     echo "EMC device: $device have one or more path in state DEAD" 
     echo
     /etc/powermt display dev=$device 
     echo
     EXITCODE=1
    else
     echo "Device $device is ALIVE"
   fi
 done
exit $EXITCODE
}


mpxio_check() {
MPXIO_DEVS="$(echo|format|egrep "EMC|SUN-LCSM" |awk '{print $2}')"
echo "Starting MPXIO checks"
echo
for dev in $MPXIO_DEVS
 do
  /usr/sbin/luxadm display /dev/rdsk/"$dev"s2 | grep -i "State" | egrep -i "UNKNOWN|UNAVALIABLE|OFFLINE" > /dev/null
   if [ $? -eq 0 ]
    then
     echo "MpXIO: device $dev has one or more path in state OFFLINE"
     EXITCODE=1
    else
     echo "Device $dev ONLINE"
   fi
 done
exit $EXITCODE
}

vxvm_check() {
VXVM_MPATH="$(/usr/sbin/vxdisk path | grep -v "DISABLED" | grep 't[0-9]\{2,\}' | awk '{print $2}')"
echo "Starting Veritas mpathing checks"
echo
for dev in $VXVM_MPATH
 do
  DEV_NPATHS=`/usr/sbin/vxdisk list $dev | grep numpaths | awk '{print $2}'`
   if [ $DEV_NPATHS -lt 2 ]
   then
     echo "Veritas: device $dev has one or more path in state OFFLINE"
     EXITCODE=1
   else
     echo "Device $dev ONLINE"
   fi
 done
exit $EXITCODE
}

pkginfo -q EMCpower
POWERPATH_CHECK=$?

pkginfo -q VRTSvxvm
VXPATH_CHECK=$?

echo|format|egrep "EMC|SUN-LCSM" > /dev/null
MPXIOPATH_CHECK=$?

if [ $POWERPATH_CHECK -eq 0 ]
 then
   power_check

 elif [ $VXPATH_CHECK -eq 0 ] 
   then
   vxvm_check

 elif [ MPXIOPATH_CHECK -eq 0 ]
   then
   mpxio_check

 else
   echo "No supported mpath technology found"
   exit $EXITCODE
fi
