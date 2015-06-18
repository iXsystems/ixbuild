#!/bin/sh

# Check if we have sourced the variables yet
if [ -z $PDESTDIR ]
then
  . ../freenas.cfg
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

which pixz >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing pixz.."
  rc_halt "pkg install -y archivers/pixz"
fi

pkg info textproc/py-sphinx >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing py-sphinx.."
  rc_halt "pkg install -y textproc/py-sphinx"
fi

pkg info textproc/py-sphinxcontrib-httpdomain >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing py-sphinxcontrib-httpdomain.."
  rc_halt "pkg install -y textproc/py-sphinxcontrib-httpdomain"
fi

pkg info textproc/py-sphinx-intl >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing py-sphinx-intl.."
  rc_halt "pkg install -y textproc/py-sphinx-intl"
fi

pkg info "print/tex-formats" >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing print/tex-formats.."
  rc_halt "pkg install -y print/tex-formats"
fi

pkg info "print/tex-dvipsk" >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing print/tex-dvipsk.."
  rc_halt "pkg install -y print/tex-dvipsk"
fi

pkg info "devel/gmake" >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing devel/gmake.."
  rc_halt "pkg install -y devel/gmake"
fi

pkg info "lang/python" >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing lang/python.."
  rc_halt "pkg install -y lang/python"
fi

pkg info "www/npm" >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing www/npm.."
  rc_halt "pkg install -y www/npm"
fi

pkg info "pxz" >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing archivers/pxz.."
  rc_halt "pkg install -y archivers/pxz"
fi

pkg info "grub2-bhyve" >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing grub2-bhyve.."
  rc_halt "pkg install -y sysutils/grub2-bhyve"
fi

pkg info "misc/compat9x" >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing misc/compat9x.."
  rc_halt "pkg install -y misc/compat9x"
fi

pkg info "emulators/virtualbox-ose" >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing emulators/virtualbox-ose.."
  rc_halt "pkg install -y emulators/virtualbox-ose"
fi

pkg info "emulators/virtualbox-ose-kmod" >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing emulators/virtualbox-ose-kmod.."
  rc_halt "pkg install -y emulators/virtualbox-ose-kmod"
fi

pkg info "ftp/curl" >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing ftp/curl.."
  rc_halt "pkg install -y ftp/curl"
fi

pkg info "shells/bash" >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing shells/bash.."
  rc_halt "pkg install -y shells/bash"
fi
