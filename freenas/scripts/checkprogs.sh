#!/usr/bin/env sh

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

which wget >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing wget.."
  rc_halt "pkg-static install -y wget"
fi

pkg info -q lang/python27 >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing lang/python27.."
  rc_halt "pkg-static install -y python27"
fi

pkg info python >/dev/null 2>&1
if [ "$?" != "0" ]; then
  echo "Installing lang/python.."
  rc_halt "pkg-static install -y python"
fi

pkg info python36 >/dev/null 2>&1
if [ "$?" != "0" ]; then
  echo "Installing python36.."
  rc_halt "pkg-static install -y python36"
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

pkg info -q compat9x-amd64 >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing compat9x-amd64.."
  rc_halt "pkg-static install -y compat9x-amd64"
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

which pip3.6 > /dev/null 2>&1
if [ "$?" != "0" ]; then
  echo "Installing pip"
  rc_halt "python3.6 -m ensurepip"
fi

#FIXME: waiting for fixed python3.6 in executor
: '
python3.6 -c "import requests" >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing requests"
  rc_halt "pip3.6 install requests"
fi

python3.6 -c "import pytest" >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing pytest"
  rc_halt "pip3.6 install pytest"
fi

python3.6 -c "import pytest_cache" >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing pytest-cache"
  rc_halt "pip3.6 install pytest-cache"
fi

python3.6 -c "import pytest_capturelog" >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing pytest-capturelog"
  rc_halt "pip3.6 install pytest-capturelog"
fi

python3.6 -c "import pytest_localserver" >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing pytest-localserver"
  rc_halt "pip3.6 install pytest-localserver"
fi

python3.6 -c "import pytest_runner" >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing pytest-runner"
  rc_halt "pip3.6 install pytest-runner"
fi

python3.6 -c "import pytest_cache" >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing pytest-cache"
  rc_halt "pip3.6 install pytest-cache"
fi

python3.6 -c "import pytest_tornado" >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing pytest-tornado"
  rc_halt "pip3.6 install pytest-tornado"
fi

python3.6 -c "import pytest_xdist" >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing pytest-xdist"
  rc_halt "pip3.6 install pytest-xdist"
fi
'
