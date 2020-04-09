#!/bin/bash
# Monitoring script for CUPS printing
#
# Execution: Cron job/manual
# Reports if a disabled printer is found and enables it
#
# Author
# ----------- ---------  ----------------------------------------------
# Daniel Zhelev  08302012  Script creation

EXCLUDE_PRINTERS=""
DISABLED_PRINTERS=$(lpstat -t | grep disabled | awk '{ print $2; }')

for PRINTER in $DISABLED_PRINTERS
do
        /bin/logger "Printer $PRINTER found disabled. Enabling!"
        /usr/bin/enable $PRINTER 
        if [ $? -eq 0 ]
        then
        /bin/logger "Printer $PRINTER has been enabled."
        else
        /bin/logger "Printer $PRINTER cannot be enabled. Check manually."
        fi
done
