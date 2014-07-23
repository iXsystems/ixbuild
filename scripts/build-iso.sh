#!/bin/sh
# PC-BSD Build configuration settings

# Where is the pcbsd-build program installed
PROGDIR="`realpath | sed 's|/scripts||g'`" ; export PROGDIR

# Copy .dist files if necessary
if [ ! -e "${PROGDIR}/pcbsd.cfg" ] ; then
   cp ${PROGDIR}/pcbsd.cfg.dist ${PROGDIR}/pcbsd.cfg
fi
if [ ! -e "${PROGDIR}/repo.conf" ] ; then
   cp ${PROGDIR}/repo.conf.dist ${PROGDIR}/repo.conf
fi

cd ${PROGDIR}/scripts

# Source the config file
. ${PROGDIR}/pcbsd.cfg

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

  # If we are using a local repo, we should update the jail now
  if [ "$PKGREPO" = "local" ] ; then
    update_poudriere_jail
  fi
}

do_iso() 
{
  echo "Building ISO file"

  rm ${PROGDIR}/iso/* >/dev/null 2>/dev/null

  # Are we building both TrueOS / PC-BSD images?
  if [ -z "$SYSBUILD" -o "$SYSBUILD" = "BOTH" ] ; then

    local oSys="$SYSBUILD"
    SYSBUILD="pcbsd" ; export SYSBUILD
    ${PROGDIR}/scripts/9.freesbie.sh
    if [ $? -ne 0 ] ; then
      echo "Script failed!"
      exit 1
    fi
    SYSBUILD="trueos" ; export SYSBUILD
    ${PROGDIR}/scripts/9.freesbie.sh
    if [ $? -ne 0 ] ; then
      echo "Script failed!"
      exit 1
    fi
    SYSBUILD="$oSys" ; export SYSBUILD
  else
    ${PROGDIR}/scripts/9.freesbie.sh
    if [ $? -ne 0 ] ; then
      echo "Script failed!"
      exit 1
    fi
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
     sync ; sleep 1
  fi

  # Check if we have a portstree to build
  poudriere ports -l | grep -q "^$POUDPORTS"
  if [ $? -ne 0 ] ; then
     sh ${PROGDIR}/scripts/portbuild.sh portsnap
     sync ; sleep 1
  fi

  sh ${PROGDIR}/scripts/portbuild.sh all
  if [ $? -ne 0 ] ; then
    echo "Script failed!"
    exit 1
  fi
}

do_ports_meta()
{
  sh ${PROGDIR}/scripts/portbuild.sh meta
  exit $?
}

do_ports_all()
{
  sh ${PROGDIR}/scripts/portbuild.sh portsnap
  exit $?
}

do_pbi-index()
{
  sh ${PROGDIR}/scripts/portbuild.sh pbi-index
  exit $?
}

do_ports_pcbsd()
{
  if [ ! -d "${PJPORTSDIR}" ] ; then
     sh ${PROGDIR}/scripts/portbuild.sh portsnap
     if [ $? -ne 0 ] ; then
        exit 1
     fi
  fi
  sh ${PROGDIR}/scripts/portbuild.sh portmerge
  exit $?
}

do_check_ports()
{
  check_essential_pkgs "NO"
  exit $?
}

echo "Operation started: `date`"

TARGET="$1"
if [ -z "$TARGET" ] ; then TARGET="all"; fi

case $TARGET in
 all|ALL) do_world 
	  if [ "$PKGREPO" = "local" ] ; then
	    do_ports
	    if [ $? -ne 0 ] ; then exit 1 ; fi
	  fi
          do_iso ;;
   world) do_world ;;
     iso) do_iso ;;
   ports) do_ports
          exit $?
          ;;
check-ports) do_check_ports ;;
ports-meta-only) do_ports_meta ;;
ports-update-all) do_ports_all ;;
ports-update-pcbsd) do_ports_pcbsd ;;
pbi-index) do_pbi-index ;;
   clean) do_clean ;;
    menu) sh ${PROGDIR}/scripts/menu.sh ;;
       *) ;;
esac


echo "Operation finished: `date`"
exit 0
