#!/bin/bash
# Author: Daniel Zhelev @ https://zhelev.biz
##### Collect stats from BigIP LTMs - works for version 11.5 and above


LTM_ADDR=
USER=
PASS=
POOL_LIST=pool_list.txt
POOL_STATS=pool_stats.txt


die()
{
        echo "$@" >&2
        exit 1
}


check()
{
nc -w 5 $LTM_ADDR 443
[[ $? -ne 0 ]] && die "Cannot connect to LB: $LTM_ADDR"

curl -s -k -u $USER:$PASS -X GET https://$LTM_ADDR/mgmt/tm/ltm/ -f >/dev/null
[[ $? -ne 0 ]] && die "Cannot login to LB: $LTM_ADDR"
}


collect()
{

  for (( i=0 ; i<3 ; i++ ))
  do
        curl -f -s -k -u $USER:$PASS -X GET https://$LTM_ADDR/mgmt/tm/ltm/pool/ | tr ',' '\n' | grep name | cut -d ':' -f2 | tr -d '"|,| ' > ${POOL_LIST} && break
  done
  [[ $? -ne 0 ]] && die "cannot get pool list"


  while read pool
  do
        echo "$pool: $(curl -s -k -u $USER:$PASS -X GET https://$LTM_ADDR/mgmt/tm/ltm/pool/$pool/stats | tr ',' '\n' | grep 'bits' | cut -d ":" -f3 | tr -d '"|}' | tr '\n' ' ')" >> ${POOL_STATS}

  done < ${POOL_LIST}


}

reset()
{
curl -s -k -u $USER:$PASS -H "Content-Type: application/json" -X POST -d '{"command":"reset-stats"}' https://$LTM_ADDR/mgmt/tm/ltm/pool >/dev/null
echo "Done"
}



while getopts "t:" flag
do
case "$flag" in
  t) TYPE="$OPTARG" ;;
esac
done

      if [ -z "$TYPE" ]
        then
         echo "Please provide collection type -t reset/collect"
         die
       elif [ $TYPE == "collect" ]
         then
          check
          collect
       elif [ $TYPE == "reset" ]
         then
          check
          reset
      fi
