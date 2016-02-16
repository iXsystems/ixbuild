#!/bin/sh

if [ $(id -u) != "0" ] ; then
  echo "This must be run as root!"
  exit 1
fi

which sudo >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing sudo.."
  pkg install -y security/sudo
fi

which sudo >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Failed installing sudo!"
  exit 1
fi

which git >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Installing git.."
  pkg install -y devel/git
fi

which git >/dev/null 2>/dev/null
if [ "$?" != "0" ]; then
  echo "Failed installing git!"
  exit 1
fi

if [ -d "/ixbuild" ] ; then
  echo "/ixbuild already exists! Remove this directory to continue!"
  exit 1
fi

git clone --depth=1 https://github.com/iXsystems/ixbuild.git /ixbuild
if [ $? -ne 0 ] ; then
  echo "Failed cloning into /ixbuild"
  exit 1
fi

if [ ! -d "/usr/local/etc/sudoers.d" ] ; then
  mkdir -p /usr/local/etc/sudoers.d
fi
cp ./sudo-ixbuild /usr/local/etc/sudoers.d/ixbuild
chmod 644 /usr/local/etc/sudoers.d/ixbuild

# Copy over the build.conf defaults
cp /ixbuild/build.conf.dist /ixbuild/build.conf

echo ""
echo "**************************************************************"
echo "Jenkins node is ready to begin builds. Use sudo /ixbuild/jenkins.sh <cmd> <build target> {production|edge}"
echo "Build targets in /ixbuild/builds/"
echo "Run /ixbuild/jenkins.sh for list of build commands"
echo " "
echo "EXAMPLE: % sudo /ixbuild/jenkins.sh freenas-combo freenas-9 production"
