#!/bin/bash
### Prevent: e1000e 0000:01:00.1 enp1s0f1: Detected Hardware Unit Hang:
# Author: Daniel Zhelev @ https://zhelev.biz
LOG_PREFIX="$(date +%Y-%m-%d\ %H:%M:%S) $HOSTNAME"

die()
{
   echo "$LOG_PREFIX $@" >&2
   exit 1
}

test -x /usr/bin/netstat || die "Please install netstat"
test -x /usr/sbin/ethtool || die "Please install ethtool"

e1000e_nics=$(/usr/bin/netstat -ni | awk '{print $1}' | grep enp)
for e1000e_nic in $e1000e_nics
 do
  ethtool -K $e1000e_nic gso off gro off tso off || die "Error applying ethtool conf for adapter: $e1000e_nic"
 done
exit 0
