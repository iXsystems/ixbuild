#!/bin/sh

# Where is the pcbsd-build program installed
PROGDIR="`realpath | sed 's|/scripts$||g'`" ; export PROGDIR

# Source our functions
. ${PROGDIR}/scripts/functions.sh

# Make sure we have all the required packages installed
${PROGDIR}/scripts/checkprogs.sh

if [ ! -d "${PROGDIR}/tmp" ] ; then
  mkdir ${PROGDIR}/tmp
fi


# Set the default build directory
FNASBDIR="/freenas"
export FNASBDIR

# Figure out the upgrade name
echo "Finding Update directory..."
if [ -d "${FNASBDIR}/_BE/release" ] ; then
  UPMANI=`find ${FNASBDIR}/_BE/release | grep FreeNAS-MANIFEST`
  UPDIR="$(dirname $UPMANI)"/Packages
fi

# If no upgrade found
if [ -z "$UPDIR" -o ! -d "$UPDIR" ] ; then
  exit_err "Failed locating upgrade files, did 'make release' work?"
fi

# Is this TrueNAS or FreeNAS?
echo $UPDIR | grep -q "TrueNAS"
if [ $? -eq 0 ] ; then
   export FLAVOR="TRUENAS"
else
   export FLAVOR="FREENAS"
fi

echo "Using Upgrade directory: $UPDIR"

