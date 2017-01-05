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
  rc_halt "pkg-static install git"
fi

which grub-mkrescue >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing grub-mkrescue.."
  rc_halt "pkg-static install -y grub2-pcbsd"
fi

pkg info -q sysutils/grub2-efi
if [ "$?" != "0" ]; then
  echo "Installing sysutils/grub2-efi"
  rc_halt "pkg-static install -y grub2-efi"
fi

which mkisofs >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing cdrtools.."
  rc_halt "pkg-static install -y cdrtools"
fi

which xorriso >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing xorriso.."
  rc_halt "pkg-static install -y xorriso"
fi

pkg info "devel/gmake" >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing devel/gmake.."
  rc_halt "pkg-static install -y gmake"
fi

which curl >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing ftp/curl.."
  rc_halt "pkg-static install -y curl"
fi

which bash >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing shells/bash.."
  rc_halt "pkg-static install -y bash"
fi

which js24 >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing lang/spidermonkey24.."
  rc_halt "pkg-static install -y spidermonkey24"
fi

pkg info -q lang/python27 >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing lang/python27.."
  rc_halt "pkg-static install -y python27"
fi

which python >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing lang/python.."
  rc_halt "pkg-static install -y python"
fi

which python3 >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing python3.."
  rc_halt "pkg-static install -y python3"
fi

pkg info -q textproc/py27-sphinx >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing sphinx.."
  rc_halt "pkg-static install -y py27-sphinx"
fi

pkg info -q textproc/py27-sphinx-intl >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing sphinx-intl.."
  rc_halt "pkg-static install -y py27-sphinx-intl"
fi

pkg info -q textproc/py27-sphinx_numfig >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing sphinx_numfig.."
  rc_halt "pkg-static install -y py27-sphinx_numfig"
fi

pkg info -q textproc/py27-sphinx_rtd_theme >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing sphinx_rtd_theme.."
  rc_halt "pkg-static install -y py27-sphinx_rtd_theme"
fi

pkg info -q textproc/py27-sphinx_wikipedia >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing sphinx_wikipedia.."
  rc_halt "pkg-static install -y py27-sphinx_wikipedia"
fi

pkg info -q textproc/py27-sphinxcontrib-httpdomain >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing sphinxcontrib-httpdomain.."
  rc_halt "pkg-static install -y py27-sphinxcontrib-httpdomain"
fi

pkg info -q misc/compat9x >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing misc/compat9x.."
  rc_halt "pkg-static install -y compat9x"
fi

which pxz >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing archivers/pxz"
  rc_halt "pkg-static install -y pxz"
fi

which poudriere >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing ports-mgmt/poudriere-devel"
  rc_halt "pkg-static install -y poudriere-devel"
fi

which sshpass >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing security/sshpass"
  rc_halt "pkg-static install -y sshpass"
fi

which py27-pytest >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing devel/py27-pytest"
  rc_halt "pkg-static install -y py27-pytest"
fi

which py27-pytest-cache >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing devel/py27-pytest-cache"
  rc_halt "pkg-static install -y py27-pytest-cache"
fi

which py27-pytest-capturelog >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing devel/py27-pytest-capturelog"
  rc_halt "pkg-static install -y py27-pytest-capturelog"
fi

which py27-pytest-localserver >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing devel/py27-pytest-localserver"
  rc_halt "pkg-static install -y py27-pytest-localserver"
fi

which py27-pytest-runner >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing devel/py27-pytest-runner"
  rc_halt "pkg-static install -y py27-pytest-runner"
fi

which py27-pytest-cache >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing devel/py27-pytest-cache"
  rc_halt "pkg-static install -y py27-pytest-timeout"
fi

which py27-pytest-tornado >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing devel/py27-pytest-tornado"
  rc_halt "pkg-static install -y py27-pytest-tornado"
fi

which py27-pytest-xdist >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing devel/py27-pytest-xdist"
  rc_halt "pkg-static install -y py27-pytest-xdist"
fi

which py27-pip >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing devel/py27-pip"
  rc_halt "pkg-static install -y py27-pip"
fi

