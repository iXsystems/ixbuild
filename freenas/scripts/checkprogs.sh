#!/bin/sh

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

which grub-mkrescue >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing grub-mkrescue.."
  rc_halt "pkg install -y sysutils/grub2-pcbsd"
fi

which mkisofs >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing cdrtools.."
  rc_halt "pkg install -y sysutils/cdrtools"
fi

which xorriso >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing xorriso.."
  rc_halt "pkg install -y sysutils/xorriso"
fi

which VBoxManage >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing emulators/virtualbox-ose.."
  rc_halt "pkg install -y emulators/virtualbox-ose"
fi

pkg info "emulators/virtualbox-ose-kmod" >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing emulators/virtualbox-ose-kmod.."
  rc_halt "pkg install -y emulators/virtualbox-ose-kmod"
fi

which curl >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing ftp/curl.."
  rc_halt "pkg install -y ftp/curl"
fi

which bash >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing shells/bash.."
  rc_halt "pkg install -y shells/bash"
fi

which js24 >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing lang/spidermonkey24.."
  rc_halt "pkg install -y lang/spidermonkey24"
fi

which python3 >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing python3.."
  rc_halt "pkg install -y python3"
fi
