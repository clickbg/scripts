#!/usr/bin/env bash
## Simple script to control NUT connected UPS
# Author: Daniel Zhelev @ https://zhelev.biz
###################

UPS_USER=
UPS_PASSWORD=
UPS_NAME=
UPS_HOST=localhost


######### Config end
die()
 {
   echo "$@" >&2
   exit 1
  }

UPS_CMD()
 {
  UPSCMD=$(which upscmd)
  test -e $UPSCMD || die "upscmd not found in your path. Please install NUT first."
  $UPSCMD -u$UPS_USER -p$UPS_PASSWORD $UPS_NAME@$UPS_HOST $@ 2>&1
  return $?
 }

UPS_CMD_LIST()
 {
  UPSCMD=$(which upscmd)
  test -e $UPSCMD || die "upscmd not found in your path. Please install NUT first."
  $UPSCMD -l -u$UPS_USER -p$UPS_PASSWORD $UPS_NAME@$UPS_HOST
  return $?
 }


UPS_CLIENT()
 {
  UPSC=$(which upsc)
  test -e $UPSC || die "upsc not found in your path. Please install NUT first."
  $UPSC $UPS_NAME@$UPS_HOST 2>&1 | grep -v '^Init SSL'
  return $?
 }

case "$1" in
  list_commands)
   UPS_CMD_LIST
   exit $?
   ;;
  issue_command)
   UPS_CMD $2 $3
   exit $?
   ;;
  ups_status)
   UPS_CLIENT
   exit $?
   ;;
  *)
   echo "Unrecognized input. Supported options: issue_command, list_commands, ups_status"
   exit 1
   ;;
esac
