#!/bin/sh
# PC-BSD Build configuration settings

# Where is the pcbsd-build program installed
PROGDIR="`realpath | sed 's|/scripts||g'`" ; export PROGDIR

# Copy .dist files if necessary
if [ ! -e "${PROGDIR}/pcbsd.cfg" ] ; then
   cp ${PROGDIR}/pcbsd.cfg.dist ${PROGDIR}/pcbsd.cfg
fi
if [ ! -e "${PROGDIR}/pkg.conf" ] ; then
   cp ${PROGDIR}/pkg.conf.dist ${PROGDIR}/pkg.conf
fi
if [ ! -e "${PROGDIR}/pkg-pubkey.cert.dist" ] ; then
   cp ${PROGDIR}/pkg-pubkey.cert.dist ${PROGDIR}/pkg-pubkey.cert
fi

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

do_ports()
{
  echo "Building ports"

  if [ ! -e "${DISTDIR}/base.txz" ] ; then
     exit_err "You must create a world before running poudriere"
  fi

  # Make sure the jail is created
  poudriere jail -l | grep -q $PBUILD
  if [ $? -ne 0 ] ; then
    update_poudriere_jail
  fi

  # Check if we have a portstree to build
  if [ ! -d "${PJPORTSDIR}" ] ; then
     sh ${PROGDIR}/scripts/portbuild.sh portsnap
  fi

  sh ${PROGDIR}/scripts/portbuild.sh all
  if [ $? -ne 0 ] ; then
    echo "Script failed!"
    exit 1
  fi
}

do_ports_all()
{
  sh ${PROGDIR}/scripts/portbuild.sh portsnap
}

do_ports_pcbsd()
{
  if [ ! -d "${PJPORTSDIR}" ] ; then
     sh ${PROGDIR}/scripts/portbuild.sh portsnap
  fi
  sh ${PROGDIR}/scripts/portbuild.sh portmerge
}

echo "Operation started: `date`"

TARGET="$1"
if [ -z "$TARGET" ] ; then TARGET="all"; fi

case $TARGET in
 all|ALL) do_world 
	  if [ "$PKGREPO" = "local" ] ; then
	    do_ports
	  fi
          do_iso ;;
   world) do_world ;;
     iso) do_iso ;;
   ports) do_ports ;;
ports-update-all) do_ports_all ;;
ports-update-pcbsd) do_ports_pcbsd ;;
   clean) do_clean ;;
    menu) sh ${PROGDIR}/scripts/menu.sh ;;
       *) ;;
esac


echo "Operation finished: `date`"
exit 0
