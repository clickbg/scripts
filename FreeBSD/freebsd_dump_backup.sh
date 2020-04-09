#!/usr/local/bin/bash
# Author: Daniel Zhelev @ https://zhelev.biz
# Filesystems to backup
INCLUDE="/dev/mirror/groota /dev/mirror/grootg /dev/mirror/grootd /dev/mirror/gjaila /dev/mirror/gjailb"
# Where to create the backups; It should already exist
BACKUP_DIR=/backup/weekly/backups
# Backup device
B_DEVICE=/dev/da0s1
# Backup mouting point
B_POINT=/backup/weekly
# Maximum disk usage
ALARM=95
# EMAIL address to send results to
EMAILADDRESS=root

############## SYSTEM VARIABLES ##############
NOW="$(date +"%d-%m-%Y")"
HOST="$(hostname)"
DUMP="$(which dump)"
BZIP2="$(which bzip2)"
TAR="$(which tar)"
####### Mounting the backup partition #######
echo "## Starting weekly backup $NOW for Wolfdale ##"
echo "###################################################"
echo "## Mounting backup device ##"
echo "###################################################"
mount_msdosfs $B_DEVICE $B_POINT
sleep 5
# Usage
usep=$(df $B_DEVICE | grep -v Filesystem | awk '{ print $5 " " $5 }' | awk '{ print $1}' | cut -d'%' -f1 )
####### Deleting images older than 61 days
echo "## Deleting files older than 61 days ##"
echo "###################################################"
find $B_POINT -xdev -mtime +61 -type f -exec ls -laSh {} \;
find $B_POINT -xdev -mtime +61 -type f -exec rm {} \;
echo "###################################################"

# Does backup dir exist?
if [ ! -d $BACKUP_DIR ]
then
#Send Email and Exit
echo "The specified backup directory $BACKUP_DIR does not exist. Operation canceled." | mail -s "Backup aborted" $EMAILADDRESS
echo "The specified backup directory $BACKUP_DIR does not exist. Operation canceled."
umount $B_POINT
sync
/sbin/fsck_msdosfs -y $B_DEVICE
exit 1
fi

# Does the backup device has enough memory?
if [ $usep -ge $ALARM ]
then
#Send Email and Exit
echo "The specified backup directory $B_POINT does not have enough memory. Operation canceled." | mail -s "Backup aborted" $EMAILADDRESS
echo "The specified backup directory $B_POINT does not have enough memory. Operation canceled."
umount $B_POINT
sync
/sbin/fsck_msdosfs -y $B_DEVICE
exit 1
fi

# Starting the backup
echo "## Dumping filesystems ##"
echo "###################################################"

for fs in $INCLUDE
do
FSNAME="$(echo $fs | cut -d'/' -f4)"
FSFILE="$BACKUP_DIR/$FSNAME.$HOST.$NOW.bz2"
$DUMP -0Lauf - $fs | $BZIP2 &gt; $FSFILE
done

echo "## Securing files ##"
echo "###################################################"
chmod -R 400 $B_POINT
echo "###################################################"
echo "## Backed up today ##"
echo "###################################################"
find $B_POINT -xdev -mtime -1 -type f -exec ls -laSh {} \;
echo "###################################################"
echo "## Free space on backup partition ##"
echo "###################################################"
df -h $B_POINT
echo "###################################################"
echo "## Unmouting partitions and cleaning them ##"
echo "###################################################"
umount $B_POINT
sync
/sbin/fsck_msdosfs -y $B_DEVICE
echo "###################################################"
echo "## Backup complete $NOW ##"
echo "###################################################"
exit 0
