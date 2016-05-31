#!/bin/sh

# Source our functions
if [ -z "$PROGDIR" ] ; then
  . functions.sh
else
  . ${PROGDIR}/scripts/functions.sh
fi

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

pkg info -q sysutils/grub2-efi
if [ "$?" != "0" ]; then
  echo "Installing sysutils/grub2-efi"
  rc_halt "pkg install -y sysutils/grub2-efi"
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

pkg info -q emulators/virtualbox-ose-kmod
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

pkg info -q lang/python27 >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing lang/python27.."
  rc_halt "pkg install -y lang/python27"
fi

which python >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing lang/python.."
  rc_halt "pkg install -y lang/python"
fi

which python3 >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing python3.."
  rc_halt "pkg install -y python3"
fi

pkg info -q textproc/py-sphinx >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing sphinx.."
  rc_halt "pkg install -y textproc/py-sphinx"
fi

pkg info -q textproc/py-sphinx-intl >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing sphinx-intl.."
  rc_halt "pkg install -y textproc/py-sphinx-intl"
fi

pkg info -q textproc/py-sphinx_numfig >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing sphinx_numfig.."
  rc_halt "pkg install -y textproc/py-sphinx_numfig"
fi

pkg info -q textproc/py-sphinx_rtd_theme >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing sphinx_rtd_theme.."
  rc_halt "pkg install -y textproc/py-sphinx_rtd_theme"
fi

pkg info -q textproc/py-sphinx_wikipedia >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing sphinx_wikipedia.."
  rc_halt "pkg install -y textproc/py-sphinx_wikipedia"
fi

pkg info -q textproc/py-sphinxcontrib-httpdomain >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing sphinxcontrib-httpdomain.."
  rc_halt "pkg install -y textproc/py-sphinxcontrib-httpdomain"
fi

pkg info -q misc/compat9x >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing misc/compat9x.."
  rc_halt "pkg install -y misc/compat9x"
fi

which node >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing www/node012.."
  rc_halt "pkg install -y www/node012"
fi

which npm >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing www/npm012.."
  rc_halt "pkg install -y www/npm012"
fi

which pxz >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing archivers/pxz"
  rc_halt "pkg install -y archivers/pxz"
fi

which poudriere >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing ports-mgmt/poudriere-devel"
  rc_halt "pkg install -y ports-mgmt/poudriere-devel"
fi

which sshpass >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing security/sshpass"
  rc_halt "pkg install -y security/sshpass"
fi
