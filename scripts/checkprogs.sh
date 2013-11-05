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
  rc_halt "pkg install sysutils/grub2"
fi

which xorriso >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing xorriso.."
  rc_halt "pkg install sysutils/xorriso"
fi

if [ ! -d "/usr/local/lib/grub/x86_64-efi" ]; then
  echo "Installing grub2-efi.."
  rc_halt "pkg install sysutils/grub2-efi"
fi
