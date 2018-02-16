#!/bin/sh

if [ $(id -u) != "0" ] ; then
  echo "This must be run as root!"
  exit 1
fi

echo "How do you wish to prep this system?"
echo "node   - Builder to connect to existing Jenkins server"
echo "master - Deploy Jenkins server and run local node"
echo -e "node>\c"
read ans
if [ -z "$ans" ] ; then ans="node"; fi
case $ans in
  node|NODE) PREPTYPE="NODE";;
  master|MASTER) PREPTYPE="MASTER";;
  *) ;;
esac

which sudo >/dev/null 2>/dev/null
if [ $? -ne 0 ]; then
  echo "Installing sudo.."
  pkg install -y security/sudo
fi

which sudo >/dev/null 2>/dev/null
if [ $? -eq 0 ]; then
  echo "Failed installing sudo!"
  exit 1
fi

which pigz >/dev/null 2>/dev/null
if [ $? -eq 0 ]; then
  pkg install -y pigz
fi

which pigz >/dev/null 2>/dev/null
if [ $? -eq 0 ]; then
  echo "Failed installing pigz!"
  exit 1
fi

which git >/dev/null 2>/dev/null
if [ $? -ne 0 ]; then
  echo "Installing git.."
  pkg install -y devel/git
fi

pkg info -q python3 >/dev/null 2>/dev/null
if [ $? -ne 0 ]; then
  echo "Installing python3.."
  pkg install -y python3
fi

which jq >/dev/null 2>/dev/null
if [ $? -ne 0 ]; then
  echo "Installing jq.."
  pkg install -y jq
fi


which git >/dev/null 2>/dev/null
if [ $? -ne 0 ]; then
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

if [ "$PREPTYPE" = "MASTER" ] ; then
  pkg info -q jenkins >/dev/null 2>/dev/null
  if [ "$?" != "0" ]; then
    pkg install -y jenkins
    if [ "$?" != "0" ]; then
      echo "Failed installing jenkins!"
      exit 1
    fi
  fi

  # Get the pre-built jenkins config
  rm -rf /usr/local/jenkins >/dev/null 2>/dev/null
  echo "Downloading Jenkins config..."
  fetch -o /tmp/jenkins-master.txz http://update.cdn.pcbsd.org/jenkins-config/master.txz
  if [ $? -ne 0 ] ; then
     echo "Failed downloading Jenkins config!"
     exit 1
  fi
  tar xvpf /tmp/jenkins-master.txz -C /usr/local >/dev/null 2>/dev/null
  if [ $? -ne 0 ] ; then
     echo "Failed extracting Jenkins config!"
     exit 1
  fi
  rm /tmp/jenkins-master.txz
  chown -R jenkins:jenkins /usr/local/jenkins

  # Enable Jenkins
  sysrc -f /etc/rc.conf jenkins_enable="YES"

  # Start Jenkins
  service jenkins start
  if [ $? -ne 0 ] ; then
     echo "Failed starting Jenkins!"
     exit 1
  fi

  echo ""
  echo "**************************************************************"
  echo "Jenkins is started and running on http://localhost:8180/jenkins/"
  echo "You should connect and setup a username / password!"
  echo "**************************************************************"

else
  echo ""
  echo "**************************************************************"
  echo "Jenkins node is ready to begin builds."
  echo " "
  echo "Build targets in /ixbuild/builds/"
  echo "Run /ixbuild/jenkins.sh for list of build commands"
  echo " "
  echo "EXAMPLE:"
  echo "sudo /ixbuild/jenkins.sh freenas-combo freenas-9"
fi


