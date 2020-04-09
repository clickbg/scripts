#!/usr/bin/env bash
# Author: Daniel Zhelev @ https://zhelev.biz
###################

HDDTEMP=$(which hddtemp)
LMSENSORS=$(which sensors)
LOG_PREFIX="$(date +%Y-%m-%d\ %H:%M:%S) $HOSTNAME"

die()
{
   echo "$LOG_PREFIX $@" >&2
   exit 1
}

check_lm_sensor()
{
test -e $LMSENSORS || die "Please install lm-sensors first"
local SENSOR_NAME=$1
local SENSOR_LABEL=$2
local TEMP_THRESH=$3

[[ -z $SENSOR_NAME ]] && die "Please specify sensor name. Run sensors -u to obtain lm_sensors label. Example : $0 sensor temp1_input LABEL TEMP_THRESH"
[[ -z $SENSOR_LABEL ]] && SENSOR_LABEL=$SENSOR_NAME

LMSENSORS_OUTPUT=$($LMSENSORS -uA | grep -oP "(?<=$SENSOR_NAME: )[0-9]+")
[[ "$LMSENSORS_OUTPUT" =~ ^-?[0-9]+$ ]] || die "Sensors output not a integer: $LMSENSORS_OUTPUT. Please check your parameters."


if [[ ! -z $TEMP_THRESH ]]
then
 [[ "$TEMP_THRESH" =~ ^-?[0-9]+$ ]] || die "Temperature threshold not an integer: $TEMP_THESH. Please check your parameters."
  if [[ $LMSENSORS_OUTPUT -ge $TEMP_THRESH ]]
   then
    echo "$LOG_PREFIX WARNING: Temperature threshold of $TEMP_THRESH'C reached!"
    echo "$LOG_PREFIX WARNING: $SENSOR_LABEL : $LMSENSORS_OUTPUT'C"
    return 1
  else
    echo "$LOG_PREFIX INFO: $SENSOR_LABEL : $LMSENSORS_OUTPUT'C"
    return 0
  fi
else
 echo "$LOG_PREFIX INFO: $SENSOR_LABEL : $LMSENSORS_OUTPUT'C"
 return 0
fi

}


check_hdd()
{
test -e $HDDTEMP || die "Please install hddtemp first"
local HDD_PATH=$1
local HDD_LABEL=$2
local TEMP_THRESH=$3

[[ -z $HDD_PATH ]] && die "Please specify HDD path."
[[ -z $HDD_LABEL ]] && HDD_LABEL=$HDD_PATH

HDDTEMP_OUTPUT=$($HDDTEMP -w -n $HDD_PATH)
[[ "$HDDTEMP_OUTPUT" =~ ^-?[0-9]+$ ]] || die "Hddtemp output not a integer: $HDDTEMP_OUTPUT. Please check your parameters."


if [[ ! -z $TEMP_THRESH ]]
then
 [[ "$TEMP_THRESH" =~ ^-?[0-9]+$ ]] || die "Temperature threshold not an integer: $TEMP_THESH. Please check your parameters."
  if [[ $HDDTEMP_OUTPUT -ge $TEMP_THRESH ]]
   then
    echo "$LOG_PREFIX WARNING: Temperature threshold of $TEMP_THRESH'C reached!"
    echo "$LOG_PREFIX WARNING: $HDD_LABEL : $HDDTEMP_OUTPUT'C"
    return 1
   else
    echo "$LOG_PREFIX INFO: $HDD_LABEL : $HDDTEMP_OUTPUT'C"
    return 0
  fi
else
 echo "$LOG_PREFIX INFO: $HDD_LABEL : $HDDTEMP_OUTPUT'C"
 return 0
fi
}



#################################################### End functions definition

case ${1-:} in
        lm_sensor)
                check_lm_sensor $2 $3 $4
                exit $?
                ;;
        disk)
                check_hdd $2 $3 $4
                exit $?
                ;;
        help|?|--help|-h)
                echo "$LOG_PREFIX Usage: $0 [ lm_sensor LM_SENSOR_NAME LABEL TEMPERATURE_THRESHOLD | disk DISK_PATH LABEL TEMPERATURE_THRESHOLD)"
                exit 0
                ;;
        ""|*)
                echo "$LOG_PREFIX Invalid argument"
                $0 help
                exit 1
                ;;
esac
