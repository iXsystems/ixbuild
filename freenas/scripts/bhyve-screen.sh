#!/usr/bin/env sh

PROGDIR="`dirname "`realpath "`dirname "$0"`"`"`"
MFSFILE="$1"
BUILDTAG="$2"

grub-bhyve -m ${PROGDIR}/tmp/device.map -r cd0 -M 2048M $BUILDTAG

# Daemonize the bhyve process
daemon -p /tmp/$BUILDTAG.pid \
  bhyve \
    -AI -H -P \
    -s 0:0,hostbridge \
    -s 1:0,lpc \
    -s 2:0,virtio-net,tap0 \
    -s 3:0,virtio-blk,${MFSFILE} \
    -s 4:0,ahci-cd,${PROGDIR}/tmp/$BUILDTAG.iso \
    -l com1,stdio \
    -c 4 \
    -m 2048M $BUILDTAG

# Wait for initial bhyve startup
count=0
while :
do
  # Break from loop when the process ID file disappears
  if [ ! -e "/tmp/$BUILDTAG.pid" ] ; then break; fi

  # Break from loop if process ID is found in running processes
  pgrep -qF /tmp/$BUILDTAG.pid
  if [ $? -ne 0 ] ; then
    break;
  fi

  count=`expr $count + 1`
  if [ $count -gt 360 ] ; then break; fi
  echo -n "."

  sleep 10
done

# Cleanup the old VM
bhyvectl --destroy --vm=$BUILDTAG
