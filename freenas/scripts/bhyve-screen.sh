#!/usr/bin/env sh

if ! pkg info -q uefi-edk2-bhyve ; then
  echo "FAILED: requires bhyve, uefi-edk2-bhyve (for bootrom)"
  exit 1
fi

PROGDIR=`dirname $0`
PROGDIR=`realpath $PROGDIR`
PROGDIR=`dirname $PROGDIR`
BUILDTAG="$1"

cpu=4
ram=2048M
fw=/usr/local/share/uefi-firmware/BHYVE_UEFI.fd

if ! zfs list | grep -q tank/${BUILDTAG}vm0 ; then
  zfs create -V 8G tank/${BUILDTAG}vm0
fi

# Daemonize the bhyve process
daemon -p /tmp/$BUILDTAG.pid \
  bhyve \
    -AI -H -P \
    -s 0:0,hostbridge \
    -s 1:0,lpc \
    -s 2:0,virtio-net,tap0 \
    -s 3:0,ahci-hd,/dev/zvol/tank/${BUILDTAG}vm0 \
    -s 4:0,ahci-cd,/$BUILDTAG.iso \
    -l bootrom,${fw} \
    -c ${cpu} \
    -m ${ram} $BUILDTAG

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

exit 0
