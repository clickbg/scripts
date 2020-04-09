#!/bin/bash
# Script to monitor set of DHCP IPs and turn on or off our home cameras
# Author: Daniel Zhelev @ https://zhelev.biz

####################### Begin config
MY_PID=$$
MY_PATH=$(readlink -f $0)
MY_ROOT=$(dirname $MY_PATH)
MY_NAME=$(basename $MY_PATH)
MY_CONF="$MY_ROOT/$MY_NAME.conf"

# Load our config file
if [[ ! -r $MY_CONF ]]
 then
   echo "No config file found at $MY_CONF, please run $(basename $0) setup first and then create $MY_CONF."
   exit 1
else
   source $MY_CONF
fi

####################### End config


###################### Begin helper functions definitions


###################### Common functions


#### Generic log function.
log() {
  echo "$(date +%Y-%m-%d\ %H:%M:%S) $@" >> "$logFile"
}


#### Exit function
die()
{
   echo "$(date +%Y-%m-%d\ %H:%M:%S) $@" >&2
   log $@
   return 1
   exit 1
}


#### Skip loop on error
skip()
{
   echo "$(date +%Y-%m-%d\ %H:%M:%S) $@" >&2
   log $@
   return 1
   break
}


#### Setup files and directories
setup()
{
echo "$(date +%Y-%m-%d\ %H:%M:%S) INFO: Firstrun started, creating directories and files."

test -e $SNMPWALK || die "CRITICAL: Please install snmpwalk first."
test -e $JQ || die "CRITICAL: Please install jq first."
test -e $CURL || die "CRITICAL: Please install curl first."

  if [ ! -d "$logDir" ]; then
    mkdir "$logDir"
    chmod 700 $logDir
    chown $autocamUser:$autocamUser $logDir
  fi
  if [ ! -d "$stateDir" ]; then
    mkdir "$stateDir"
    chmod 700 $stateDir
    chown $autocamUser:$autocamUser $stateDir
  fi
  if [ ! -f "$stateFile" ]; then
    touch "$stateFile"
    chmod 600 $stateFile
    chown $autocamUser:$autocamUser $stateFile
  fi
  if [ ! -f "$logFile" ]; then
    touch "$logFile"
    chmod 600 $logFile
    chown $autocamUser:$autocamUser $logFile
  fi
  if [ ! -f "$lockFile" ]; then
    touch "$lockFile"
    chmod 600 $lockFile
    chown $autocamUser:$autocamUser $lockFile
  fi

setup_oauth2


echo
echo "$(date +%Y-%m-%d\ %H:%M:%S) INFO: Firstrun completed."
}



###################### Honeywell API functions
#### Function to setup oAuth2 for our app
setup_oauth2()
{
#### Get api keys and setup OAUTH2
  read -p "Application URL: " API_APP_URL
  read -p "Application API key (consumer key): " API_KEY
  read -p "Application API secret (consumer secret): " API_SECRET
  read -p "Honeywell API URL: " API_URL

  local GET_REDIRECT_URL=$($CURL -s --connect-timeout $API_TIMEOUT -X GET -Ls -o /dev/null -w %{url_effective} \
  "$API_URL/oauth2/authorize?response_type=code&redirect_uri=$API_APP_URL&client_id=$API_KEY")

  echo
  echo "Open in browser and retrive access code from URL: $GET_REDIRECT_URL"
  echo

  read -p "Access code: " API_AUTHORIZATION_KEY

  local GET_REFRESH_TOKEN=$($CURL -s -H --connect-timeout $API_TIMEOUT -X POST --header "Authorization: $API_BASE64_CLIENT_SECRET" \
  --header "Accept: application/json" --header "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=authorization_code&code=$API_AUTHORIZATION_KEY&redirect_uri=$API_APP_URL" "$API_URL/oauth2/token" | $JQ -re '.refresh_token')
  [[ $? -ne 0 ]] && skip "CRITICAL: Unable to get Honeywell Lyric API refresh token. Error : $GET_REFRESH_TOKEN. Skipping...."

  echo
  echo "Generated oAuth2 config:"
  echo
  echo "API_URL=$API_URL"
  echo "API_KEY=$API_KEY"
  echo "API_SECRET=$API_SECRET"
  echo "API_APP_URL=$API_APP_URL"
  echo "API_REFRESH_TOKEN=$GET_REFRESH_TOKEN"
  echo "API_BASE64_CLIENT_SECRET=$(printf $API_KEY:$API_SECRET | base64)"

  echo
  echo "Save those in your config."
  echo
}


#### Function to get API access token
get_api_token()
{
  local GET_ACCESS_TOKEN=$($CURL -s -H --connect-timeout $API_TIMEOUT -X POST --header "Authorization: $API_BASE64_CLIENT_SECRET" \
  --header "Content-Type: application/x-www-form-urlencoded" -d "grant_type=refresh_token&refresh_token=$API_REFRESH_TOKEN" \
  "$API_URL/oauth2/token" | $JQ -re '.access_token')
  [[ $? -ne 0 ]] && skip "CRITICAL: Unable to get Honeywell Lyric API access token. Error : $GET_ACCESS_TOKEN. Skipping...."

  echo $GET_ACCESS_TOKEN
}


#### Function to get camera config
get_camera_config()
{
  local API_CAMERA_DEVICE_ID=$@

  local GET_CAMERA_CONFIG=$($CURL -s --connect-timeout $API_TIMEOUT -H "Authorization: Bearer $API_ACCESS_TOKEN" \
  -X GET "$API_URL/v2/devices/cameras/$API_CAMERA_DEVICE_ID/config?apikey=$API_KEY&locationId=$API_LOCATION_ID")
  echo $GET_CAMERA_CONFIG | $JQ -e .deviceId >/dev/null 2>&1
  [[ $? -ne 0 ]] && skip "WARNING: Failed to get config for Camera with ID : $API_CAMERA_DEVICE_ID. Error : $GET_CAMERA_CONFIG. Skipping..."

  echo $GET_CAMERA_CONFIG
}


#### Function to get the friendly name of a camera
get_camera_friendly_name()
{
 local API_CAMERA_DEVICE_ID=$@

 local CAMERA_FRIENDLY_NAME=$($CURL -s --connect-timeout $API_TIMEOUT -H "Authorization: Bearer $API_ACCESS_TOKEN" \
 -X GET "$API_URL/v2/devices/cameras?apikey=$API_KEY&locationId=$API_LOCATION_ID" | jq -re --arg API_CAMERA_DEVICE_ID \
 "$API_CAMERA_DEVICE_ID" '.[] | select(.deviceID==$API_CAMERA_DEVICE_ID)|.userDefinedDeviceName')
 [[ $? -ne 0 ]] && skip "WARNING: Failed to get friendly name for Camera with ID : $API_CAMERA_DEVICE_ID. Error : $CAMERA_FRIENDLY_NAME. Skipping..."

 echo $CAMERA_FRIENDLY_NAME
}


#### Function to turn off a camera
turn_off_camera()
{
 local API_CAMERA_DEVICE_ID=$@

 # We need to get the current Camera config.
 local CAMERA_CONFIG=$(get_camera_config $API_CAMERA_DEVICE_ID)

 # Check if the Camera is not already off
 local PRIVACY_MODE=$(echo $CAMERA_CONFIG | $JQ -er '.privacyMode')
    if [[ "$PRIVACY_MODE" == "off" ]]
     then
      local POST_CAMERA_CONFIG=$CAMERA_CONFIG
      # Turn on privacy
      local POST_CAMERA_CONFIG=$(echo $POST_CAMERA_CONFIG | $JQ -er '.privacyMode = "on"')
      # Turn on the led light
      local POST_CAMERA_CONFIG=$(echo $POST_CAMERA_CONFIG | $JQ -er '.ledStatus = "on"')

      # And post the _entire_ config again. Thanks Honeywell.
      local POST_CAMERA_OFFLINE=$($CURL -s -o /dev/null -w "%{http_code}" --connect-timeout $API_TIMEOUT -H "Authorization: Bearer $API_ACCESS_TOKEN" --header "Content-Type: application/json" \
      -X POST "$API_URL/v2/devices/cameras/$API_CAMERA_DEVICE_ID/config?apikey=$API_KEY&locationId=$API_LOCATION_ID" -d "$POST_CAMERA_CONFIG")
      [[ "$POST_CAMERA_OFFLINE" != +(200|204) ]] && skip "WARNING: Failed to put Camera with ID : $API_CAMERA_DEVICE_ID offline. HTTP CODE: $POST_CAMERA_OFFLINE"
    fi

}


#### Function to turn on a camera
turn_on_camera()
{
 local API_CAMERA_DEVICE_ID=$@

 # We need to get the current Camera config.
 local CAMERA_CONFIG=$(get_camera_config $API_CAMERA_DEVICE_ID)

 # Check if the Camera is not already off
   local PRIVACY_MODE=$(echo $CAMERA_CONFIG | $JQ -er '.privacyMode')
    if [[ "$PRIVACY_MODE" == "on" ]]
     then
      local POST_CAMERA_CONFIG=$CAMERA_CONFIG
      # Turn off privacy
      local POST_CAMERA_CONFIG=$(echo $POST_CAMERA_CONFIG | $JQ -er '.privacyMode = "off"')
      # Turn off the led light
      local POST_CAMERA_CONFIG=$(echo $POST_CAMERA_CONFIG | $JQ -er '.ledStatus = "off"')


      # And post the _entire_ config again. Thanks Honeywell.
      local POST_CAMERA_ONLINE=$($CURL -s -o /dev/null -w "%{http_code}" --connect-timeout $API_TIMEOUT -H "Authorization: Bearer $API_ACCESS_TOKEN" --header "Content-Type: application/json" \
      -X POST "$API_URL/v2/devices/cameras/$API_CAMERA_DEVICE_ID/config?apikey=$API_KEY&locationId=$API_LOCATION_ID" -d "$POST_CAMERA_CONFIG")
      [[ "$POST_CAMERA_ONLINE" != +(200|204) ]] && skip "WARNING: Failed to put Camera with ID : $API_CAMERA_DEVICE_ID online. HTTP CODE: $POST_CAMERA_OFFLINE"
    fi

}


#### Function to report the status of a camera
get_camera_status()
{
 local API_CAMERA_DEVICE_ID=$@

 # We need to get the current Camera config.
 local CAMERA_CONFIG=$(get_camera_config $API_CAMERA_DEVICE_ID)

 # Now lets report the status
   local PRIVACY_MODE=$(echo $CAMERA_CONFIG | $JQ -er '.privacyMode')
    case "$PRIVACY_MODE" in
       on) echo "$API_CAMERA_DEVICE_ID : OFFLINE"
        ;;
       off) echo "$API_CAMERA_DEVICE_ID : ONLINE"
        ;;
       *)  echo "$API_CAMERA_DEVICE_ID : UNKNOWN"
        ;;
    esac

}



###################### End Honeywell API functions


###################### Mikrotik SNMP functions
#### SNMP command shortcut
snmp_cmd()
{
 $SNMPWALK -m ALL -u $SNMP_USER -v $SNMP_VERSION -a $SNMP_AUTH_PROTOCOL -A $SNMP_AUTH_PASS -l $SNMP_AUTH_TYPE -x $SNMP_ENCRYPT_PROTOCOL -X $SNMP_ENCRYPT_PASS $SNMP_IP -L n $@
}

#### Check if we have SNMP access to target
check_snmp_access()
{
  snmp_cmd -On $SNMP_RB_SYSTEM_ID_OID > /dev/null
  if [[ $? -eq 0 ]]
   then
    return 0
   else
    return 1
  fi
}

#### Function to check DHCP lease status
check_dhcp_lease_status()
{
 local DHCP_IP=$@

 check_snmp_access
 [[ $? -ne 0 ]] && skip "CRITICAL: Cannot connect to $SNMP_IP via SNMP. Skipping...."

  local DHCP_IP_LEASE_STATUS=$(snmp_cmd -Ovq $SNMP_RB_DHCP_LEASE_OID.$DHCP_IP)
   echo $DHCP_IP_LEASE_STATUS | grep -qw 3
    if [[ $? -eq 0 ]]
     then
      return 0
     else
      return 1
    fi
}


###################### End Mikrotik SNMP functions


###################### End helper functions definition


###################### Begin main functions definition


main()
{
 # Invalidate the LAST_USERS_HOME count if every $stateValidInterval minutes
 # We do this to be sure the cameras will be offline or online even after user interaction with them
  if [[ $(find "$stateFile" -mmin +$stateValidInterval -print) ]]
   then
     echo > $stateFile
     log "INFO: $stateValidInterval minutes passed, synchronizing the state of our cameras."
  fi
  LAST_USERS_HOME=$(<$stateFile)

 # Retrive the count of users at home right now via SNMP
  CURRENT_USERS_HOME=0
  for DHCP_IP in $DHCP_IPS
   do
    check_dhcp_lease_status $DHCP_IP
    if [[ $? -eq 0 ]]
     then
      let "CURRENT_USERS_HOME++"
    fi
   done


 # Compare the count of users at home right now and when we last ran an action aginst the cameras
 # If both are equal no further actions are needed, and if they are not we need to reevaluate whether or not the cameras should be on or off
  if [[ $CURRENT_USERS_HOME != $LAST_USERS_HOME ]]
   then
    if [[ $CURRENT_USERS_HOME -gt 0 ]]
     then

       log "INFO: $CURRENT_USERS_HOME person/s at home, shutting down the cameras."
       API_ACCESS_TOKEN=$(get_api_token)
       for API_CAMERA_DEVICE_ID in $API_CAMERAS_DEVICE_IDS
        do
         local CAMERA_FRIENDLY_NAME=$(get_camera_friendly_name $API_CAMERA_DEVICE_ID)
          try=0
           until [ $try -ge $API_RETRY ]
            do
            turn_off_camera $API_CAMERA_DEVICE_ID
            sleep 5
            get_camera_status $API_CAMERA_DEVICE_ID | grep -qw "OFFLINE"
             if [ $? -eq 0 ]
              then
               log "INFO: Camera $CAMERA_FRIENDLY_NAME - $API_CAMERA_DEVICE_ID is now OFFLINE."
               break
             else
               let "try++"
               skip "WARNING: Shutdown of camera $CAMERA_FRIENDLY_NAME - $API_CAMERA_DEVICE_ID failed. Retry $try of $API_RETRY"
             fi
          done
       done
      echo $CURRENT_USERS_HOME > $stateFile

    else

       log "INFO: $CURRENT_USERS_HOME person/s at home, starting the cameras."
       API_ACCESS_TOKEN=$(get_api_token)
       for API_CAMERA_DEVICE_ID in $API_CAMERAS_DEVICE_IDS
        do
         local CAMERA_FRIENDLY_NAME=$(get_camera_friendly_name $API_CAMERA_DEVICE_ID)
          try=0
           until [ $try -ge $API_RETRY ]
            do
            turn_on_camera $API_CAMERA_DEVICE_ID
            sleep 5
            get_camera_status $API_CAMERA_DEVICE_ID | grep -qw "ONLINE"
             if [ $? -eq 0 ]
              then
               log "INFO: Camera $CAMERA_FRIENDLY_NAME - $API_CAMERA_DEVICE_ID is now ONLINE."
               break
             else
               let "try++"
               skip "WARNING: Startup of camera $CAMERA_FRIENDLY_NAME - $API_CAMERA_DEVICE_ID failed. Retry $try of $API_RETRY"
             fi
            done
        done
       echo $CURRENT_USERS_HOME > $stateFile
    fi

  fi


}


#### Function to execute the main function in a loop
payload()
{
 while [ true ]; do
  checkforterm
  main
  sleep $checkInterval
 done
}


###################### End main functions definition



###################### Begin daemon functions definion



CR="
"
SP=" "
OIFS=$IFS

function daemonize() {
        echo $MY_PID > $pidFile
        exec 3>&-           # close stdin
        exec 2>>$logFile # redirect stderr
        exec 1>>$logFile # redirect stdout
        log "INFO: Daemonizing"
}

function checkforterm() {
        if [ -f $killFile ]; then
                log "INFO: Terminating gracefully"
                rm $pidFile
                rm $killFile
                kill $MY_PID
                exit 0
        fi
        sleepcount=0
        while [ -f $waitFile ]; do
                let sleepcount=$sleepcount+1
                let pos=$sleepcount%10
                if [ $pos -eq 0 ]; then
                        log "INFO: Sleeping..."
                        log "INFO: Sleeping..." >> $logFile
                fi
                if [ -f $killFile ]; then
                        rm $waitFile
                        checkforterm
                fi
                sleep 1
        done
}




case $1 in
        pause-daemon)
                touch $waitFile
                ;;
        resume-daemon)
                rm $waitFile
                ;;
        restart-daemon)
                $0 stop-daemon
                $0 start-daemon
                ;;
        start-daemon)
                if [ -f $blockFile ]; then
                        echo "$(date +%Y-%m-%d\ %H:%M:%S) INFO: Daemon execution has been disabled"
                        exit 0
                fi


                test -e $lockFile || die "CRITICAL: $MY_NAME not configured. Please run $(basename $0) setup first."
                (
                flock -n 200 || die "CRITICAL: Another instance of $(basename $0) is running. Exiting...."
                # Drop privileges
                cd $MY_ROOT
                umask 077
                # Invalidate the cameras state
                echo > $stateFile
                su $autocamUser -s /bin/bash -c "$MY_ROOT/$MY_NAME run &"
                $0 status-daemon 1>/dev/null 2>/dev/null
                ECODE=$?
                waitcount=0
                if [ "$waitcountmax" = "" ]; then waitcountmax=5; fi
                while [ $ECODE -ne 0 ]; do
                        sleep 1
                        let waitcount=$waitcount+1
                        if [ $waitcount -lt $waitcountmax ]; then
                                $0 status-daemon 1>/dev/null 2>/dev/null
                                ECODE=$?
                        else
                                ECODE=0
                        fi
                done
                $0 status-daemon 1>/dev/null 2>/dev/null
                if [ $? -ne 0 ]; then
                        echo "$(date +%Y-%m-%d\ %H:%M:%S) CRITICAL: Daemon startup failed"
                        log "CRITICAL: Daemon startup failed"
                        exit 1
                else
                        echo "$(date +%Y-%m-%d\ %H:%M:%S) INFO: Daemon Started"
                        log "INFO: Daemon Started"
                fi
                exec 3>&- # close stdin
                exec 2>&- # close stderr
                exec 1>&- # close stdout
                exit 0
                ) 200> $lockFile

                ;;
        disable-daemon)
                touch $blockFile
                $0 stop-daemon
                ;;
        enable-daemon)
                if [ -f $blockFile ]; then rm $blockFile; fi
                ;;
        stop-daemon)
                echo "$(date +%Y-%m-%d\ %H:%M:%S) INFO: Terminating daemon..."
                $0 status-daemon 1>/dev/null 2>/dev/null
                if [ $? -ne 0 ]; then
                        echo "$(date +%Y-%m-%d\ %H:%M:%S) INFO: Process is not running"
                        exit 0
                fi
                touch $killFile
                $0 status-daemon 1>/dev/null 2>/dev/null
                ECODE=$?
                waitcount=0
                if [ "$waitcountmax" = "" ]; then waitcountmax=30; fi
                while [ $ECODE -eq 0 ]; do
                        sleep 1
                        let waitcount=$waitcount+1
                        if [ $waitcount -lt $waitcountmax ]; then
                                $0 status-daemon 1>/dev/null 2>/dev/null
                                ECODE=$?
                        else
                                ECODE=1
                        fi
                done
                $0 status-daemon 1>/dev/null 2>/dev/null
                if [ $? -eq 0 ]; then
                        PID=$(cat $pidFile)
                        kill $PID
                        rm $pidFile
                        rm $killFile
                        echo "$(date +%Y-%m-%d\ %H:%M:%S) CRITICAL: Process Killed"
                        log "CRITICAL: Terminating forcefully"
                        exit 0;
                else
                        echo "$(date +%Y-%m-%d\ %H:%M:%S) INFO: Process exited gracefully"
                fi
                ;;
        status-daemon)
                if [ -f $blockFile ]; then
                        echo "$(date +%Y-%m-%d\ %H:%M:%S) INFO: Daemon execution disabled"
                fi
                if [ ! -f $pidFile ]; then
                        echo "$(date +%Y-%m-%d\ %H:%M:%S) CRITICAL: $MY_NAME is not running"
                        exit 1
                fi
                pgrep -l -f "$MY_NAME run" | grep -q -E "^$(cat $pidFile) "
                if [ $? -eq 0 ]; then
                        echo "$(date +%Y-%m-%d\ %H:%M:%S) INFO: $MY_NAME is running with PID "$($0 pid)
                        exit 0
                else
                        echo "$(date +%Y-%m-%d\ %H:%M:%S) CRITICAL: $MY_NAME is not running (PIDFILE mismatch)"
                        exit 1
                fi
                ;;
        status-cameras)
                API_ACCESS_TOKEN=$(get_api_token)
                 for API_CAMERA_DEVICE_ID in $API_CAMERAS_DEVICE_IDS
                  do
                   CAMERA_FRIENDLY_NAME=$(get_camera_friendly_name $API_CAMERA_DEVICE_ID)
                   echo "$(date +%Y-%m-%d\ %H:%M:%S) INFO: $CAMERA_FRIENDLY_NAME - $(get_camera_status $API_CAMERA_DEVICE_ID)"
                  done
                ;;
        status)
                LAST_USERS_HOME=$(<$stateFile)
                echo "$(date +%Y-%m-%d\ %H:%M:%S) INFO: $LAST_USERS_HOME person/s at home"
                $0 status-cameras
                $0 status-daemon
                ;;
        stop-cameras)
                  API_ACCESS_TOKEN=$(get_api_token)
                   for API_CAMERA_DEVICE_ID in $API_CAMERAS_DEVICE_IDS
                    do
                     CAMERA_FRIENDLY_NAME=$(get_camera_friendly_name $API_CAMERA_DEVICE_ID)
                     try=0
                     until [ $try -ge $API_RETRY ]
                      do
                       turn_off_camera $API_CAMERA_DEVICE_ID
                       sleep 2
                       get_camera_status $API_CAMERA_DEVICE_ID | grep -qw "OFFLINE"
                        if [ $? -eq 0 ]
                         then
                          echo "$(date +%Y-%m-%d\ %H:%M:%S) INFO: Camera $CAMERA_FRIENDLY_NAME - $API_CAMERA_DEVICE_ID is now OFFLINE."
                          break
                        else
                          let "try++"
                          echo "$(date +%Y-%m-%d\ %H:%M:%S) WARNING: Shutdown of camera $CAMERA_FRIENDLY_NAME - $API_CAMERA_DEVICE_ID failed. Retry $try of $API_RETRY"
                        fi
                      done
                    done
                ;;
        start-cameras)
                  API_ACCESS_TOKEN=$(get_api_token)
                   for API_CAMERA_DEVICE_ID in $API_CAMERAS_DEVICE_IDS
                    do
                     CAMERA_FRIENDLY_NAME=$(get_camera_friendly_name $API_CAMERA_DEVICE_ID)
                     try=0
                     until [ $try -ge $API_RETRY ]
                      do
                       turn_on_camera $API_CAMERA_DEVICE_ID
                       sleep 2
                       get_camera_status $API_CAMERA_DEVICE_ID | grep -qw "ONLINE"
                        if [ $? -eq 0 ]
                         then
                          echo "$(date +%Y-%m-%d\ %H:%M:%S) INFO: Camera $CAMERA_FRIENDLY_NAME - $API_CAMERA_DEVICE_ID is now ONLINE."
                          break
                        else
                          let "try++"
                          echo "$(date +%Y-%m-%d\ %H:%M:%S) WARNING: Startup of camera $CAMERA_FRIENDLY_NAME - $API_CAMERA_DEVICE_ID failed. Retry $try of $API_RETRY"
                        fi
                      done
                    done
                ;;
        setup)
                setup
                ;;
        log|stdout)
                if [ -f $logFile ]; then
                        tail -f $logFile
                else
                        echo "$(date +%Y-%m-%d\ %H:%M:%S) INFO: No stdout output yet"
                fi
                ;;
        pid)
                if [ -f $pidFile ]; then
                        cat $pidFile
                else
                        echo "$(date +%Y-%m-%d\ %H:%M:%S) CRITICAL: No pidfile found"
                fi
                ;;
        run)
                daemonize
                payload
                ;;
        help|?|--help|-h)
                echo "$(date +%Y-%m-%d\ %H:%M:%S) INFO: Non-interactive usage: $0 [ start-daemon | stop-daemon | restart-daemon | pause-daemon | resume-daemon | disable-daemon | enable-daemon | status-daemon"
                echo "$(date +%Y-%m-%d\ %H:%M:%S) INFO: Interactive usage: $0 [ stop-cameras | start-cameras | status-cameras | log | setup ]"
                exit 0
                ;;
        *)
                echo "$(date +%Y-%m-%d\ %H:%M:%S) INFO: Invalid argument"
                $0 help
                ;;
esac
###################### End daemon functions definion

