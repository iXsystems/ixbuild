#!/bin/sh
# PC-BSD Build configuration settings

# Where is the pcbsd-build program installed
PROGDIR="`realpath | sed 's|/scripts||g'`" ; export PROGDIR

# Source the config file
. ../pcbsd.cfg

cd ${PROGDIR}/scripts

# First, lets check if we have all the required programs to build an ISO
. ${PROGDIR}/scripts/functions.sh

# Check if we have required programs
sh ${PROGDIR}/scripts/checkprogs.sh
cStat=$?
if [ $cStat -ne 0 ] ; then exit $cStat; fi

do_world() {

  echo "Starting build of FreeBSD/TrueOS"
  ${PROGDIR}/scripts/1.createworld.sh
  if [ $? -ne 0 ] ; then
    echo "Script failed!"
    exit 1
  fi
}

do_iso() 
{
  echo "Building ISO file"
  ${PROGDIR}/scripts/9.freesbie.sh
  if [ $? -ne 0 ] ; then
    echo "Script failed!"
    exit 1
  fi
}

do_clean()
{
  rm ${PROGDIR}/tmp/* 2>/dev/null
  rm ${PROGDIR}/tmp/All/* 2>/dev/null
}


echo "Operation started: `date`"

TARGET="$1"
if [ -z "$TARGET" ] ; then TARGET="all"; fi

case $TARGET in
 all|ALL) do_world 
          do_iso ;;
   world) do_world ;;
     iso) do_iso ;;
   clean) do_clean ;;
       *) ;;
esac


echo "Operation finished: `date`"
exit 0
