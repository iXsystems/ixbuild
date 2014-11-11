#!/bin/sh

# Check if we have sourced the variables yet
if [ -z $PDESTDIR ]
then
  . ../pcbsd.cfg
fi

# Source our functions
. ${PROGDIR}/scripts/functions.sh

# Make sure we have some  directories we need
mkdir -p ${PROGDIR}/iso >/dev/null 2>/dev/null
mkdir -p ${PROGDIR}/log >/dev/null 2>/dev/null

which git >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing git.."
  rc_halt "pkg install devel/git"
fi

which zip >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing zip.."
  rc_halt "pkg install archivers/zip"
fi

which grub-mkrescue >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing grub-mkrescue.."
  rc_halt "pkg install sysutils/grub2-pcbsd"
fi

which xorriso >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing xorriso.."
  rc_halt "pkg install sysutils/xorriso"
fi

which pixz >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing pixz.."
  rc_halt "pkg install archivers/pixz"
fi

if [ "$PKGREPO" = "local" ] ; then
  which poudriere >/dev/null 2>/dev/null
  if [ "$?" != "0" ]; then
    echo "Installing poudriere.."
    rc_halt "pkg install ports-mgmt/poudriere"
  fi
fi
