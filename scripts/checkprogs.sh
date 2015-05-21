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
  rc_halt "pkg install -y archivers/zip"
fi

which grub-mkrescue >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing grub-mkrescue.."
  rc_halt "pkg install -y sysutils/grub2-pcbsd"
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
  #rc_halt "pkg install -y textproc/py-sphinx-intl"
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

if [ "$PKGREPO" = "local" -o "$PKGREPO" = "localpkg" ] ; then
  which poudriere >/dev/null 2>/dev/null
  if [ "$?" != "0" ]; then
    echo "Installing poudriere.."
    rc_halt "pkg install -y ports-mgmt/poudriere"
  fi
fi
