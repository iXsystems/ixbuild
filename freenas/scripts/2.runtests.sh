#!/bin/sh

# Where is the pcbsd-build program installed
PROGDIR="`realpath | sed 's|/scripts||g'`" ; export PROGDIR

# Source our functions
. ${PROGDIR}/scripts/functions.sh

if [ ! -d "${PROGDIR}/tmp" ] ; then
  mkdir ${PROGDIR}/tmp
fi

# Figure out the ISO name
ISOFILE=`find /tmp/fnasb/_BE/release | grep \.iso$`

# Create the automatic ISO installer
cd ${PROGDIR}/tmp
${PROGDIR}/scripts/create-auto-install.sh ${ISOFILE}
if [ $? -ne 0 ] ; then
  exit_err "Failed creating auto-install ISO!"
fi

# Now lets spin-up bhyve and do an installation
######################################################
MFSFILE="${PROGDIR}/tmp/freenas-disk0.img"
echo "Creating $MFSFILE"
rc_halt "truncate -s 5000M $MFSFILE"


# Just in case the install hung, we don't need to be waiting for over an hour
echo "Performing bhyve installation..."
count=0
daemon -f -p /tmp/vminstall.pid sh /usr/share/examples/bhyve/vmrun.sh -c 2 -m 2048M -d ${MFSFILE} -i -I ${PROGDIR}/tmp/freenas-auto.iso vminstall
while :
do
  if [ ! -e "/tmp/vminstall.pid" ] ; then break; fi

  pgrep -qF /tmp/vminstall.pid
  if [ $? -ne 0 ] ; then
        break;
  fi

  count=`expr $count + 1`
  if [ $count -gt 360 ] ; then bhyvectl --destroy --vm=vminstall ; fi
  echo -e ".\c"

  sleep 10
done

# Check that this device seemed to install properly
dSize=`du -m ${MFSFILE} | awk '{print $1}'`
if [ $dSize -lt 10 ] ; then
   # if the disk image is too small, installation didn't work, bail out!
   echo "bhyve install failed!"
   exit 1
fi

