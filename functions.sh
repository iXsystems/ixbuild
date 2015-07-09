#!/bin/sh

# Set the repo we pull for build / tests
GITREPO="https://github.com/iXsystems/ix-tests.git"

cleanup_workdir()
{
  if [ -z "$MASTERWRKDIR" ] ; then return 0; fi
  if [ ! -d "$MASTERWRKDIR" ] ; then return 0 ; fi
  if [ "$MASTERWRKDIR" = "/" ] ; then return 0 ; fi

  # Cleanup any leftover mounts
  for i in `mount | grep -q "on ${MASTERWRKDIR}/" | awk '{print $1}' | tail -r`
  do
    umount -f $i
  done

  # Should be done with unmounts
  mount | grep -q "on ${MASTERWRKDIR}/"
  if [ $? -ne 0 ] ; then
    rm -rf ${MASTERWRKDIR}
    chflags -R noschg ${MASTERWRKDIR} 2>/dev/null
    rm -rf ${MASTERWRKDIR}
  fi
}

exit_clean()
{
  cleanup_workdir
  exit 1
}

if [ "$TYPE" != "ports-tests" ] ; then

  if [ -z "$BUILD" -o -z "$BRANCH" ] ; then
    echo "Missing BUILD / BRANCH"
    exit_clean
  fi

  if [ ! -d "${BDIR}/${BUILD}" ] ; then
    echo "Invalid BUILD dir: $BUILD"
    exit_clean
  fi

  # Source build conf and set some vars
  cd ${BDIR}/${BUILD}

  if [ "$TYPE" = "freenas" -o "$TYPE" = "freenas-tests" ] ; then
    . freenas.cfg
  else
    . pcbsd.cfg
  fi


  # Set the variables to reference poudrire jail locations
  if [ -z "$POUDRIEREJAILVER" ] ; then
    POUDRIEREJAILVER="$TARGETREL"
  fi
  case $TYPE in
    jail|pkg) WORLDTREL="$POUDRIEREJAILVER" ;;
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
    PKGSTAGE="${SFTPFINALDIR}/pkg/${WORLDTREL}/amd64"
    ISOSTAGE="${SFTPFINALDIR}/iso/${TARGETREL}/amd64"
    FBSDISOSTAGE="${SFTPFINALDIR}/freebsd-iso/${TARGETREL}/amd64"
    WORKPKG="${SFTPWORKDIR}/pkg/${WORLDTREL}/amd64"
    WORKWORLD="${SFTPWORKDIR}/world/${WORLDTREL}/amd64"
  elif [ "$BRANCH" = "EDGE" -o "$BRANCH" = "edge" ] ; then
    PKGSTAGE="${SFTPFINALDIR}/pkg/${WORLDTREL}/edge/amd64"
    ISOSTAGE="${SFTPFINALDIR}/iso/${TARGETREL}/edge/amd64"
    FBSDISOSTAGE="${SFTPFINALDIR}/freebsd-iso/${TARGETREL}/edge/amd64"
    WORKPKG="${SFTPWORKDIR}/pkg/${WORLDTREL}/edge/amd64"
    WORKWORLD="${SFTPWORKDIR}/world/${WORLDTREL}/amd64"
  elif [ "$BRANCH" = "ENTERPRISE" -o "$BRANCH" = "enterprise" ] ; then
    PKGSTAGE="${SFTPFINALDIR}/pkg/${WORLDTREL}/enterprise/amd64"
    ISOSTAGE="${SFTPFINALDIR}/iso/${TARGETREL}/enterprise/amd64"
    FBSDISOSTAGE="${SFTPFINALDIR}/freebsd-iso/${TARGETREL}/enterprise/amd64"
    WORKPKG="${SFTPWORKDIR}/pkg/${WORLDTREL}/enterprise/amd64"
    WORKWORLD="${SFTPWORKDIR}/world/${WORLDTREL}/amd64"
  else
    echo "Invalid BRANCH"
    exit_clean
  fi
fi

create_workdir()
{
  if [ ! -d "/tmp/pcbsd-build" ] ; then
     mkdir /tmp/pcbsd-build
  fi

  MASTERWRKDIR=`mktemp -d /tmp/pcbsd-build/XXXXXXXXXXXXXXXX` 

  git clone --depth=1 ${GITREPO} ${MASTERWRKDIR}
  if [ $? -ne 0 ] ; then exit_clean; fi

  cd ${MASTERWRKDIR}
  if [ $? -ne 0 ] ; then exit_clean; fi

  case $TYPE in
    freenas|freenas-tests) TBUILDDIR="${MASTERWRKDIR}/freenas" ;;
          *) TBUILDDIR="${MASTERWRKDIR}/pcbsd" ;;
  esac

  cp ${BDIR}/${BUILD}/* ${TBUILDDIR}
  if [ $? -ne 0 ] ; then exit_clean; fi

  cd ${TBUILDDIR}
  if [ $? -ne 0 ] ; then exit_clean; fi
}
push_pkgworkdir()
{
  cd ${PPKGDIR}
  if [ $? -ne 0 ] ; then exit_clean; fi

  ssh ${SFTPUSER}@${SFTPHOST} "mkdir -p ${WORKPKG}" >/dev/null 2>/dev/null

  rsync -va --delete-delay --delay-updates -e 'ssh' . ${SFTPUSER}@${SFTPHOST}:${WORKPKG}/ >${MASTERWRKDIR}/push.log 2>${MASTERWRKDIR}/push.log
  if [ $? -ne 0 ] ; then tail -50 ${MASTERWRKDIR}/push.log ; exit_clean; fi
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
  if [ $? -ne 0 ] ; then exit_clean; fi

  rsync -va --delete-delay --delay-updates -e 'ssh' ${SFTPUSER}@${SFTPHOST}:${WORKPKG}/ . >${MASTERWRKDIR}/push.log 2>${MASTERWRKDIR}/push.log

  if [ $? -ne 0 ] ; then tail -50 ${MASTERWRKDIR}/push.log ; exit_clean; fi
}

push_world()
{
  cd ${TBUILDDIR}/fbsd-dist
  if [ $? -ne 0 ] ; then exit_clean; fi

  ssh ${SFTPUSER}@${SFTPHOST} "mkdir -p ${WORKWORLD}" >/dev/null 2>/dev/null

  rsync -va --delete-delay --delay-updates -e 'ssh' . ${SFTPUSER}@${SFTPHOST}:${WORKWORLD}/ >${MASTERWRKDIR}/push.log 2>${MASTERWRKDIR}/push.log
  if [ $? -ne 0 ] ; then tail -50 ${MASTERWRKDIR}/push.log ; exit_clean; fi

  cd ${TBUILDDIR}/fbsd-iso
  if [ $? -ne 0 ] ; then exit_clean; fi

  ssh ${SFTPUSER}@${SFTPHOST} "mkdir -p ${FBSDISOSTAGE}" >/dev/null 2>/dev/null

  rsync -va --delete-delay --delay-updates -e 'ssh' . ${SFTPUSER}@${SFTPHOST}:${FBSDISOSTAGE}/ >${MASTERWRKDIR}/push.log 2>${MASTERWRKDIR}/push.log
  if [ $? -ne 0 ] ; then tail -50 ${MASTERWRKDIR}/push.log ; exit_clean; fi
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
  if [ $? -ne 0 ] ; then exit_clean; fi

  rsync -va --delete-delay --delay-updates -e 'ssh' ${SFTPUSER}@${SFTPHOST}:${WORKWORLD}/ . >${MASTERWRKDIR}/push.log 2>${MASTERWRKDIR}/push.log
  if [ $? -ne 0 ] ; then tail -50 ${MASTERWRKDIR}/push.log ; exit_clean; fi
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
  if [ $? -ne 0 ] ; then exit_clean; fi

  rsync -va --delete-delay --delay-updates -e 'ssh' ${SFTPUSER}@${SFTPHOST}:${ISOSTAGE}/ . >${MASTERWRKDIR}/push.log 2>${MASTERWRKDIR}/push.log
  if [ $? -ne 0 ] ; then tail -50 ${MASTERWRKDIR}/push.log ; exit_clean; fi
}

jenkins_world()
{
  create_workdir

  cd ${TBUILDDIR}
  if [ $? -ne 0 ] ; then exit_clean; fi

  make world
  if [ $? -ne 0 ] ; then exit_clean; fi

  push_world

  cleanup_workdir

  exit 0
}

jenkins_jail()
{
  create_workdir

  pull_world

  cd ${TBUILDDIR}
  if [ $? -ne 0 ] ; then exit_clean; fi

  make jail
  if [ $? -ne 0 ] ; then exit_clean; fi

  cleanup_workdir

  exit 0
}

jenkins_pkg()
{
  create_workdir

  # Pull in the world directory
  pull_world

  cd ${TBUILDDIR}
  if [ $? -ne 0 ] ; then exit_clean; fi

  make ports-update-all
  if [ $? -ne 0 ] ; then exit_clean; fi

  # Pull the workdir from the cache
  pull_pkgworkdir

  cd ${TBUILDDIR}
  if [ $? -ne 0 ] ; then exit_clean; fi

  make ports
  if [ $? -ne 0 ] ; then push_pkgworkdir; exit_clean; fi

  # Push over the workdir to the cache
  push_pkgworkdir

  # Yay, success! Lets rsync the package set to staging machine
  cd $PPKGDIR
  if [ $? -ne 0 ] ; then exit_clean; fi

  ssh ${SFTPUSER}@${SFTPHOST} "mkdir -p ${PKGSTAGE}" >/dev/null 2>/dev/null

  rsync -va --delete-delay --delay-updates -e 'ssh' . ${SFTPUSER}@${SFTPHOST}:${PKGSTAGE} >${MASTERWRKDIR}/push.log 2>${MASTERWRKDIR}/push.log
  if [ $? -ne 0 ] ; then tail -50 ${MASTERWRKDIR}/push.log ; exit_clean; fi

  cleanup_workdir

  exit 0
}

jenkins_iso()
{
  create_workdir

  pull_world

  cd ${TBUILDDIR}
  if [ $? -ne 0 ] ; then exit_clean; fi

  make image
  if [ $? -ne 0 ] ; then exit_clean; fi

  # Now lets sync the ISOs
  cd ${TBUILDDIR}/iso
  if [ $? -ne 0 ] ; then exit_clean; fi

  ssh ${SFTPUSER}@${SFTPHOST} "mkdir -p ${ISOSTAGE}" >/dev/null 2>/dev/null
  rsync -va --delete-delay --delay-updates -e 'ssh' . ${SFTPUSER}@${SFTPHOST}:${ISOSTAGE} >${MASTERWRKDIR}/push.log 2>${MASTERWRKDIR}/push.log
  if [ $? -ne 0 ] ; then tail -50 ${MASTERWRKDIR}/push.log ; exit_clean; fi

  cleanup_workdir

  exit 0
}

jenkins_vm()
{
  create_workdir

  pull_world
  pull_iso

  cd ${TBUILDDIR}
  if [ $? -ne 0 ] ; then exit_clean; fi

  make vm
  if [ $? -ne 0 ] ; then exit_clean; fi

  # Now lets sync the ISOs
  cd ${TBUILDDIR}/iso
  if [ $? -ne 0 ] ; then exit_clean; fi

  ssh ${SFTPUSER}@${SFTPHOST} "mkdir -p ${ISOSTAGE}" >/dev/null 2>/dev/null
  rsync -va --delete-delay --delay-updates -e 'ssh' . ${SFTPUSER}@${SFTPHOST}:${ISOSTAGE}
  if [ $? -ne 0 ] ; then exit_clean; fi

  cleanup_workdir

  exit 0
}

jenkins_freenas()
{
  create_workdir

  cd ${TBUILDDIR}
  if [ $? -ne 0 ] ; then exit_clean; fi

  make iso
  if [ $? -ne 0 ] ; then exit_clean; fi

  # Now lets sync the ISOs
  if [ -n "$FREENASLEGACY" ] ; then
    cd /tmp/fnasb/objs
    if [ $? -ne 0 ] ; then exit_clean ; fi
    rm -rf os-base
  else
    cd /tmp/fnasb/_BE/release/
    if [ $? -ne 0 ] ; then exit_clean ; fi
  fi

  ssh ${SFTPUSER}@${SFTPHOST} "mkdir -p ${ISOSTAGE}" >/dev/null 2>/dev/null
  rsync -va --delete-delay --delay-updates -e 'ssh' . ${SFTPUSER}@${SFTPHOST}:${ISOSTAGE}
  if [ $? -ne 0 ] ; then exit_clean; fi

  cleanup_workdir

  exit 0
}

jenkins_freenas_tests()
{
  create_workdir

  cd ${TBUILDDIR}
  if [ $? -ne 0 ] ; then exit_clean ; fi

  # Now lets sync the ISOs
  if [ -d "/tmp/fnasb/_BE/release" ] ; then
    rm -rf /tmp/fnasb/_BE/release
  fi

  mkdir -p /tmp/fnasb/_BE/release
  cd /tmp/fnasb/_BE/release
  if [ $? -ne 0 ] ; then exit_clean; fi

  ssh ${SFTPUSER}@${SFTPHOST} "mkdir -p ${ISOSTAGE}" >/dev/null 2>/dev/null
  rsync -va --delete-delay --delay-updates -e 'ssh' ${SFTPUSER}@${SFTPHOST}:${ISOSTAGE} /tmp/fnasb/_BE/release/
  if [ $? -ne 0 ] ; then exit_clean ; fi

  cd ${TBUILDDIR}
  make tests
  if [ $? -ne 0 ] ; then exit_clean ; fi

  cleanup_workdir

  exit 0
}

jenkins_ports_tests()
{
  echo "Changing to $WORKSPACE"
  cd "$WORKSPACE"
  if [ $? -ne 0 ] ; then exit 1 ; fi

  ./mkports-tests.sh /usr/ports
  if [ $? -ne 0 ] ; then exit 1 ; fi

  exit 0
}
