#!/usr/bin/env bash
# Multiplatform script to monitor ZFS zpool status and capacity
# Author: Daniel Zhelev @ https://zhelev.biz
MAILTO="root"
CAPACITY_THRESHOLD="80"


###################### Internal vars
ZPOOL=$(which zpool)
MAIL=$(which mail)
EXIT=0

###################### Functions
# Error exit func
die()
{
    echo "$@" >&2
    exit 1
}

# Send mail func
send_mail()
{
    printf '%s\n' "$@" "" "`$ZPOOL list`" "" "`$ZPOOL status`" | $MAIL -s "$@" $MAILTO
    return $?
}

# Check pool/member status
health_check()
{
    for POOL in $POOLS
    do
     ERR_STATE=$($ZPOOL status | egrep -i '(DEGRADED|FAULTED|OFFLINE|UNAVAIL|REMOVED|FAIL|DESTROYED|corrupt|cannot|unrecover)')
     if [ "${ERR_STATE}" ]
     then
      MSG="$(hostname -f) - ZFS pool $POOL - HEALTH fault"
      send_mail "$MSG"
      logger "$MSG"
      let "EXIT++"
     fi
    done
}

# Check capacity func
capacity_check()
{
    for POOL in $POOLS
    do
     CURRENT_UTILIZATION=$($ZPOOL list -H -o cap $POOL | tr -d "%")
     if [[ "$CURRENT_UTILIZATION" -ge "$CAPACITY_THRESHOLD" ]]
     then
      MSG="$(hostname -f) - ZFS pool $POOL - Capacity Exceeded"
      send_mail "$MSG"
      logger "$MSG"
      let "EXIT++"
     fi
    done
}

###################### Execution
POOLS="$@"
[[ -z $POOLS ]] && die "Usage: $(readlink -f $0) pool1 pool2 poolN"
[[ -z $ZPOOL ]] && die "Please specify the path to zpool."
[[ -z $MAIL ]] && die "Please specify the path mail."
health_check
capacity_check

exit $EXIT
