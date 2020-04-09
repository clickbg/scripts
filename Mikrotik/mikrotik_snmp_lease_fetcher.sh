#!/bin/bash
# Author: Daniel Zhelev @ https://zhelev.biz
DATE=$(date +%Y-%m-%d\ %H:%M:%S)

################# Functions definitions

#### Exit function
die()
{
   echo "$DATE $@" >&2
   exit 1
}

#### SNMP command shortcut
snmp_cmd()
{
 $SNMPWALK -m ALL -u $SNMP_USER -v $SNMP_VERSION -a $SNMP_AUTH_PROTOCOL -A $SNMP_AUTH_PASS -l $SNMP_AUTH_TYPE -x $SNMP_ENCRYPT_PROTOCOL -X $SNMP_ENCRYPT_PASS $SNMP_IP $@
}

#### Check if we have SNMP access to target
check_snmp_access()
{
  snmp_cmd -On $SNMP_RB_SYSTEM_ID_OID > /dev/null
  [[ $? -ne 0 ]] && die "CRITICAL: Cannot connect to $SNMP_IP via SNMP. Exiting...."
}

#### Function to check DHCP lease status
check_dhcp_lease_status()
{
 local DHCP_IP=$@

  local DHCP_IP_LEASE_STATUS=$(snmp_cmd -Ovq $SNMP_RB_DHCP_LEASE_OID.$DHCP_IP)
   echo $DHCP_IP_LEASE_STATUS | grep -qw 3
    if [[ $? -eq 0 ]]
     then
      echo "$DHCP_IP : ONLINE"
      return 0
     else
      echo "$DHCP_IP : OFFLINE"
      return 1
    fi
}

################# End functions definition


USAGE="Usage: $0 {-c config -i IP}"

while getopts ":c:i:" flag
do
case "$flag" in
  c) CONFIG="$OPTARG" ;;
  i) IP="$OPTARG" ;;
esac
done


#### Test our env first
[ -z $IP ] && die "$USAGE"
[ -z $CONFIG ] && die "$USAGE"

test -r $CONFIG || die "Configuration file $CONFIG not found/not readable"
source $CONFIG

test -e $SNMPWALK || die "Please install snmpwalk first."

#### Execute
check_snmp_access
check_dhcp_lease_status $IP
exit $?
