#!/usr/bin/bash
# Author: Daniel Zhelev @ https://zhelev.biz
# USES BASH FUNCTIONALLITY RUN ONLY UNDER BASH
# Monitoring script for hung NFS shares
#
# Execution: Called by operator

NFS_MOUNTS=`grep nfs /etc/vfstab|awk '{print $3}'`
HAVE_NFS=`grep nfs /etc/vfstab | wc -l`
QUITCODE=0

if [ $HAVE_NFS -eq 0 ]
then
 echo "No nfs mounts found. Lucky you."
 exit 0
else
for nfs in $NFS_MOUNTS
do
  read -t10 str < <(stat -t $nfs)
  if [ $? -eq 1 ]
    then
    echo "WARNING: NFS $nfs seems to be hanged. Check with ls -al $nfs"
    QUITCODE=1
  else
    echo "OK: NFS $nfs is accessible."
  fi
done
fi

exit $QUITCODE
