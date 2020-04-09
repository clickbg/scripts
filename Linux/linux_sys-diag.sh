#!/bin/bash
# Script to run when something is wrong performance wise with your system
# Author: Daniel Zhelev @ https://zhelev.biz
LINES="=================================================================================="
COMMAND_OUTPUT_LINES="50"

echo $LINES
echo "Diagnostic information for system $(hostname -f):"
echo $LINES

printf '\n%.0s' {1..3}

echo $LINES
echo "Current LOAD-AVG"
echo $LINES
uptime
echo $LINES

printf '\n%.0s' {1..3}

echo $LINES
echo "Current SYS utilization"
echo $LINES
vmstat 1 10
echo $LINES

printf '\n%.0s' {1..3}

echo $LINES
echo "Current CPU utilization"
echo $LINES
sar 1 10
echo $LINES

printf '\n%.0s' {1..3}

echo $LINES
echo "Current DISK utilization"
echo $LINES
iostat -N -t
echo $LINES

printf '\n%.0s' {1..3}

echo $LINES
echo "Current NET utilization"
echo $LINES
netstat -i
echo $LINES

printf '\n%.0s' {1..3}

echo $LINES
echo "Diagnostic information per process:"
echo $LINES

printf '\n%.0s' {1..3}

echo $LINES
echo "Top processes by CPU usage"
echo $LINES
ps -Ao user,uid,comm,pid,pcpu,tty,stat --sort=-pcpu | head -$COMMAND_OUTPUT_LINES
echo $LINES

printf '\n%.0s' {1..3}

echo $LINES
echo "Top processes by MEM usage"
echo $LINES
ps -Ao user,uid,comm,pid,vsz,tty,stat --sort=-vsz | head -$COMMAND_OUTPUT_LINES
echo $LINES

printf '\n%.0s' {1..3}

echo $LINES
echo "Top processes by DISK usage"
echo $LINES
iotop -b -n1 | head -$COMMAND_OUTPUT_LINES

printf '\n%.0s' {1..3}

echo $LINES
echo "Current Zombie/Dead processes"
echo $LINES
ps awwxo pid=,stat=,command= | awk '$2~/^D|^Z/ { print }'
echo $LINES

printf '\n%.0s' {1..3}

echo $LINES
echo "Last 10 lines of DMESG"
echo $LINES
dmesg | tail -10
echo $LINES
