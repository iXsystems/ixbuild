#!/bin/sh
# FreeNAS Build configuration settings

# Where is the pcbsd-build program installed
PROGDIR="`realpath | sed 's|/scripts||g'`" ; export PROGDIR

# Copy .dist files if necessary
if [ ! -e "${PROGDIR}/freenas.cfg" ] ; then
   cp ${PROGDIR}/freenas.cfg.dist ${PROGDIR}/freenas.cfg
fi

cd ${PROGDIR}/scripts

# Source the config file
. ${PROGDIR}/freenas.cfg

# First, lets check if we have all the required programs to build an ISO
. ${PROGDIR}/scripts/functions.sh

# Check if we have required programs
sh ${PROGDIR}/scripts/checkprogs.sh
cStat=$?
if [ $cStat -ne 0 ] ; then exit $cStat; fi

do_iso() {

  echo "Starting build of FreeNAS"
  ${PROGDIR}/scripts/1.buildiso.sh
  if [ $? -ne 0 ] ; then
    echo "Script failed!"
    exit 1
  fi
}

echo "Operation started: `date`"

TARGET="$1"
if [ -z "$TARGET" ] ; then TARGET="all"; fi

case $TARGET in
     all) do_iso ;;
     iso) do_iso ;;
       *) ;;
esac


echo "Operation finished: `date`"
exit 0
