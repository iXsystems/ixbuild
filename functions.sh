#!/bin/sh

if [ -z "$BUILD" -o -z "$BRANCH" ] ; then
  echo "Missing BUILD / BRANCH"
  exit 1
fi

if [ ! -d "${BDIR}/${BUILD}" ] ; then
  echo "Invalid BUILD dir: $BUILD"
  exit 1
fi

# Source build conf and set some vars
cd ${BDIR}/${BUILD}
. pcbsd.cfg


# Set the variables to reference poudrire jail locations
if [ -z "$POUDRIEREJAILVER" ] ; then
  POUDRIEREJAILVER="$TARGETREL"
fi
case $TYPE in
  jail|port) WORLDTREL="$POUDRIEREJAILVER" ;;
   *) WORLDTREL="$TARGETREL" ;;
esac

# Poudriere variables
PBUILD="pcbsd-`echo $POUDRIEREJAILVER | sed 's|\.||g'`"
if [ "$ARCH" = "i386" ] ; then PBUILD="${PBUILD}-i386"; fi
if [ -z "$POUDPORTS" ] ; then
  POUDPORTS="pcbsdports" ; export POUDPORTS
fi
POUD="/usr/local/poudriere"
PJDIR="$POUD/jails/$PBUILD"
PPKGDIR="$POUD/data/packages/$PBUILD-$POUDPORTS"
PJPORTSDIR="$POUD/ports/$POUDPORTS"
export PBUILD PJDIR PJPORTSDIR PPKGDIR

# Set all the stage / work dirs
if [ "$BRANCH" = "PRODUCTION" -o "$BRANCH" = "production" ] ; then
  PKGSTAGE="${SFTPFINALDIR}/pkg/${TARGETREL}/amd64"
  ISOSTAGE="${SFTPFINALDIR}/iso/${TARGETREL}/amd64"
  WORKPKG="${SFTPWORKDIR}/pkg/${TARGETREL}/amd64"
  WORKWORLD="${SFTPWORKDIR}/world/${WORLDTREL}/amd64"
elif [ "$BRANCH" = "EDGE" -o "$BRANCH" = "edge" ] ; then
  PKGSTAGE="${SFTPFINALDIR}/pkg/${TARGETREL}/edge/amd64"
  ISOSTAGE="${SFTPFINALDIR}/iso/${TARGETREL}/edge/amd64"
  WORKPKG="${SFTPWORKDIR}/pkg/${TARGETREL}/edge/amd64"
  WORKWORLD="${SFTPWORKDIR}/world/${WORLDTREL}/amd64"
elif [ "$BRANCH" = "ENTERPRISE" -o "$BRANCH" = "enterprise" ] ; then
  PKGSTAGE="${SFTPFINALDIR}/pkg/${TARGETREL}/enterprise/amd64"
  ISOSTAGE="${SFTPFINALDIR}/iso/${TARGETREL}/enterprise/amd64"
  WORKPKG="${SFTPWORKDIR}/pkg/${TARGETREL}/enterprise/amd64"
  WORKWORLD="${SFTPWORKDIR}/world/${WORLDTREL}/amd64"
else
  echo "Invalid BRANCH"
  exit 1
fi


create_workdir()
{
  if [ ! -d "/tmp/pcbsd-build" ] ; then
     mkdir /tmp/pcbsd-build
  fi

  MASTERWRKDIR=`mktemp -d /tmp/pcbsd-build/XXXXXXXXXXXXXXXX` 

  git clone --depth=1 https://github.com/pcbsd/pcbsd-build.git ${MASTERWRKDIR}
  if [ $? -ne 0 ] ; then exit 1; fi

  cp ${BDIR}/${BUILD}/* ${MASTERWRKDIR}
  if [ $? -ne 0 ] ; then exit 1; fi

  cd ${MASTERWRKDIR}
  if [ $? -ne 0 ] ; then exit 1; fi

  case $TYPE in
    freenas) TBUILDDIR="${MASTERWRKDIR}/freenas" ;;
          *) TBUILDDIR="${MASTERWRKDIR}/pcbsd" ;;
  esac

  cd ${TBUILDDIR}
  if [ $? -ne 0 ] ; then exit 1; fi
}

cleanup_workdir()
{
  if [ -n "$MASTERWRKDIR" -a "$MASTERWRKDIR" != "/" ] ; then
    mount | grep -q "on ${MASTERWRKDIR}/"
    if [ $? -ne 0 ] ; then
      rm -rf ${MASTERWRKDIR}
    fi
  fi
}

push_pkgworkdir()
{
  cd ${PPKGDIR}
  if [ $? -ne 0 ] ; then exit 1; fi

  ssh ${SFTPUSER}@${SFTPHOST} "mkdir -p ${WORKPKG}" >/dev/null 2>/dev/null

  rsync -va --delete-delay --delay-updates -e 'ssh' . ${SFTPUSER}@${SFTPHOST}:${WORKPKG}/
  if [ $? -ne 0 ] ; then exit 1; fi
}


pull_pkgworkdir()
{
  # Check if we have any workdirs to re-sync
  ssh ${SFTPUSER}@${SFTPHOST} "ls ${WORKPKG}" >/dev/null 2>/dev/null
  if [ $? -ne 0 ] ; then
     return 0
  fi

  if [ ! -d "${PPKGDIR}" ] ; then
    mkdir -p ${PPKGDIR}
  fi

  cd ${PPKGDIR}
  if [ $? -ne 0 ] ; then exit 1; fi

  rsync -va --delete-delay --delay-updates -e 'ssh' ${SFTPUSER}@${SFTPHOST}:${WORKPKG}/ .
  if [ $? -ne 0 ] ; then exit 1; fi
}

push_world()
{
  cd ${TBUILDDIR}/fbsd-dist
  if [ $? -ne 0 ] ; then exit 1; fi

  ssh ${SFTPUSER}@${SFTPHOST} "mkdir -p ${WORKWORLD}" >/dev/null 2>/dev/null

  rsync -va --delete-delay --delay-updates -e 'ssh' . ${SFTPUSER}@${SFTPHOST}:${WORKWORLD}/
  if [ $? -ne 0 ] ; then exit 1; fi
}

pull_world()
{
  # Check if we have any workdirs to re-sync
  ssh ${SFTPUSER}@${SFTPHOST} "ls ${WORKWORLD}" >/dev/null 2>/dev/null
  if [ $? -ne 0 ] ; then
     return 0
  fi

  if [ ! -d "${TBUILDDIR}/fbsd-dist" ] ; then
    mkdir -p ${TBUILDDIR}/fbsd-dist
  fi

  cd ${TBUILDDIR}/fbsd-dist
  if [ $? -ne 0 ] ; then exit 1; fi

  rsync -va --delete-delay --delay-updates -e 'ssh' ${SFTPUSER}@${SFTPHOST}:${WORKWORLD}/ .
  if [ $? -ne 0 ] ; then exit 1; fi
}

pull_iso()
{
  # Check if we have any workdirs to re-sync
  ssh ${SFTPUSER}@${SFTPHOST} "ls ${ISOSTAGE}" >/dev/null 2>/dev/null
  if [ $? -ne 0 ] ; then
     return 0
  fi

  if [ ! -d "${TBUILDDIR}/iso" ] ; then
    mkdir -p ${TBUILDDIR}/iso
  fi

  cd ${TBUILDDIR}/iso
  if [ $? -ne 0 ] ; then exit 1; fi

  rsync -va --delete-delay --delay-updates -e 'ssh' ${SFTPUSER}@${SFTPHOST}:${ISOSTAGE}/ .
  if [ $? -ne 0 ] ; then exit 1; fi
}

jenkins_world()
{
  create_workdir

  cd ${TBUILDDIR}
  if [ $? -ne 0 ] ; then exit 1; fi

  make world
  if [ $? -ne 0 ] ; then exit 1; fi

  push_world

  cleanup_workdir

  exit 0
}

jenkins_jail()
{
  create_workdir

  pull_world

  cd ${TBUILDDIR}
  if [ $? -ne 0 ] ; then exit 1; fi

  make jail
  if [ $? -ne 0 ] ; then exit 1; fi

  cleanup_workdir

  exit 0
}

jenkins_pkg()
{
  create_workdir

  # Pull in the world directory
  pull_world

  cd ${TBUILDDIR}
  if [ $? -ne 0 ] ; then exit 1; fi

  make ports-update-all
  if [ $? -ne 0 ] ; then exit 1; fi

  # Pull the workdir from the cache
  pull_pkgworkdir

  cd ${TBUILDDIR}
  if [ $? -ne 0 ] ; then exit 1; fi

  make ports
  if [ $? -ne 0 ] ; then push_pkgworkdir; exit 1; fi

  # Push over the workdir to the cache
  push_pkgworkdir

  # Yay, success! Lets rsync the package set to staging machine
  cd $PPKGDIR
  if [ $? -ne 0 ] ; then exit 1; fi

  ssh ${SFTPUSER}@${SFTPHOST} "mkdir -p ${PKGSTAGE}" >/dev/null 2>/dev/null

  rsync -va --delete-delay --delay-updates -e 'ssh' . ${SFTPUSER}@${SFTPHOST}:${PKGSTAGE}
  if [ $? -ne 0 ] ; then exit 1; fi

  cleanup_workdir

  exit 0
}

jekins_iso()
{
  create_workdir

  pull_world

  cd ${TBUILDDIR}
  if [ $? -ne 0 ] ; then exit 1; fi

  make image
  if [ $? -ne 0 ] ; then exit 1; fi

  # Now lets sync the ISOs
  cd ${TBUILDDIR}/iso
  if [ $? -ne 0 ] ; then exit 1; fi

  ssh ${SFTPUSER}@${SFTPHOST} "mkdir -p ${ISOSTAGE}" >/dev/null 2>/dev/null
  rsync -va --delete-delay --delay-updates -e 'ssh' . ${SFTPUSER}@${SFTPHOST}:${ISOSTAGE}
  if [ $? -ne 0 ] ; then exit 1; fi

  cleanup_workdir

  exit 0
}

jekins_vm()
{
  create_workdir

  pull_world
  pull_isos

  cd ${TBUILDDIR}
  if [ $? -ne 0 ] ; then exit 1; fi

  make vm
  if [ $? -ne 0 ] ; then exit 1; fi

  # Now lets sync the ISOs
  cd ${TBUILDDIR}/iso
  if [ $? -ne 0 ] ; then exit 1; fi

  ssh ${SFTPUSER}@${SFTPHOST} "mkdir -p ${ISOSTAGE}" >/dev/null 2>/dev/null
  rsync -va --delete-delay --delay-updates -e 'ssh' . ${SFTPUSER}@${SFTPHOST}:${ISOSTAGE}
  if [ $? -ne 0 ] ; then exit 1; fi

  cleanup_workdir

  exit 0
}
