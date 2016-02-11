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

  if [ -z "$BUILD" ] ; then
    echo "Missing BUILD"
    exit_clean
  fi

  if [ ! -d "${BDIR}/${BUILD}" ] ; then
    echo "Invalid BUILD dir: $BUILD"
    exit_clean
  fi

  # Source build conf and set some vars
  cd ${BDIR}/${BUILD}

  case $TYPE in
    freenas|freenas-tests|freenas-combo)
       BRANCH="production"
       . freenas.cfg
       ;;
    *)
       if [ -z "$BRANCH" ] ; then
          echo "Missing BRANCH!"
          exit_clean
       fi
       . pcbsd.cfg
       ;;
  esac


  # Set the variables to reference poudrire jail locations
  if [ -z "$POUDRIEREJAILVER" ] ; then
    POUDRIEREJAILVER="$TARGETREL"
  fi
  case $TYPE in
    jail|pkg) WORLDTREL="$POUDRIEREJAILVER" ;;
     *) WORLDTREL="$TARGETREL" ;;
  esac
  if [ -z "$PKGVERUPLOAD" ] ; then
    PKGVERUPLOAD="$WORLDTREL"
  fi

  # Poudriere variables
  PBUILD="pcbsd-`echo $POUDRIEREJAILVER | sed 's|\.||g'`"
  if [ "$ARCH" = "i386" ] ; then PBUILD="${PBUILD}-i386"; fi
  if [ -z "$POUDPORTS" ] ; then
    POUDPORTS="pcbsdports" ; export POUDPORTS
  fi
  PPKGDIR="/synth/pkg/$PBUILD-$POUDPORTS"
  PJPORTSDIR="/synth/ports"
  export PBUILD PJPORTSDIR PPKGDIR

  # Set all the stage / work dirs
  if [ "$BRANCH" = "PRODUCTION" -o "$BRANCH" = "production" ] ; then
    PKGSTAGE="${SFTPFINALDIR}/pkg/${PKGVERUPLOAD}/amd64"
    ISOSTAGE="${SFTPFINALDIR}/iso/${TARGETREL}/amd64"
    FBSDISOSTAGE="${SFTPFINALDIR}/freebsd-iso/${TARGETREL}/amd64"
    WORKPKG="${SFTPWORKDIR}/pkg/${PKGVERUPLOAD}/amd64"
    WORKWORLD="${SFTPWORKDIR}/world/${WORLDTREL}/amd64"
  elif [ "$BRANCH" = "EDGE" -o "$BRANCH" = "edge" ] ; then
    PKGSTAGE="${SFTPFINALDIR}/pkg/${PKGVERUPLOAD}/edge/amd64"
    ISOSTAGE="${SFTPFINALDIR}/iso/${TARGETREL}/edge/amd64"
    FBSDISOSTAGE="${SFTPFINALDIR}/freebsd-iso/${TARGETREL}/edge/amd64"
    WORKPKG="${SFTPWORKDIR}/pkg/${PKGVERUPLOAD}/edge/amd64"
    WORKWORLD="${SFTPWORKDIR}/world/${WORLDTREL}/amd64"
  elif [ "$BRANCH" = "ENTERPRISE" -o "$BRANCH" = "enterprise" ] ; then
    PKGSTAGE="${SFTPFINALDIR}/pkg/${PKGVERUPLOAD}/enterprise/amd64"
    ISOSTAGE="${SFTPFINALDIR}/iso/${TARGETREL}/enterprise/amd64"
    FBSDISOSTAGE="${SFTPFINALDIR}/freebsd-iso/${TARGETREL}/enterprise/amd64"
    WORKPKG="${SFTPWORKDIR}/pkg/${PKGVERUPLOAD}/enterprise/amd64"
    WORKWORLD="${SFTPWORKDIR}/world/${WORLDTREL}/amd64"
  else
    echo "Invalid BRANCH"
    exit_clean
  fi
fi

create_workdir()
{
  if [ ! -d "/tmp/build" ] ; then
     mkdir /tmp/build
  fi

  MASTERWRKDIR=`mktemp -d /tmp/build/XXXX` 

  cocmd="git clone --depth=1 ${GITREPO} ${MASTERWRKDIR}"
  echo "Cloning with: $cocmd"
  $cocmd
  if [ $? -ne 0 ] ; then exit_clean; fi

  cd ${MASTERWRKDIR}
  if [ $? -ne 0 ] ; then exit_clean; fi

  case $TYPE in
    freenas|freenas-tests|freenas-combo) TBUILDDIR="${MASTERWRKDIR}/freenas" ;;
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

  echo "Pushing cached pkgs..."
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

  echo "Pulling cached pkgs..."
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
  # Check if the world exists
  ssh ${SFTPUSER}@${SFTPHOST} "ls ${WORKWORLD}" >/dev/null 2>/dev/null
  if [ $? -ne 0 ] ; then
     return 1
  fi

  if [ ! -d "${TBUILDDIR}/fbsd-dist" ] ; then
    mkdir -p ${TBUILDDIR}/fbsd-dist
  fi

  cd ${TBUILDDIR}/fbsd-dist
  if [ $? -ne 0 ] ; then exit_clean; fi

  rsync -va --delete-delay --delay-updates -e 'ssh' ${SFTPUSER}@${SFTPHOST}:${WORKWORLD}/ . >${MASTERWRKDIR}/push.log 2>${MASTERWRKDIR}/push.log
  if [ $? -ne 0 ] ; then tail -50 ${MASTERWRKDIR}/push.log ; exit_clean; fi
  return 0
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

  if [ -z "$1" ] ; then
    cleanup_workdir
  fi
}

jenkins_jail()
{
  create_workdir

  pull_world
  if [ $? -ne 0 ] ; then
    jenkins_world "1"
    pull_world
    if [ $? -ne 0 ] ; then
       exit_clean "Failed getting world files"
    fi
  fi

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
  if [ $? -ne 0 ] ; then
    jenkins_world "1"
    pull_world
    if [ $? -ne 0 ] ; then
       exit_clean "Failed getting world files"
    fi
  fi

  cd ${TBUILDDIR}
  if [ $? -ne 0 ] ; then exit_clean; fi

  # Check if we have a more current pkg set on the local box
  remotetime=`ssh ${SFTPUSER}@${SFTPHOST} "cat ${PKGSTAGE}/.started" 2>/dev/null`
  localtime=`cat ${PPKGDIR}/.started 2>/dev/null`
  if [ -n "$remotetime" -a -n "$localtime" ] ; then
    if [ $remotetime -lt $localtime ] ; then
      push_pkgworkdir
    fi
  fi

  cd ${TBUILDDIR}
  make ports-update-all
  if [ $? -ne 0 ] ; then exit_clean; fi

  # Pull the workdir from the cache
  pull_pkgworkdir

  cd ${TBUILDDIR}
  if [ $? -ne 0 ] ; then exit_clean; fi

  # Save the timestamp of when we started this poudriere run
  if [ ! -d "${PPKGDIR}" ] ; then mkdir -p ${PPKGDIR} ; fi
  date +"%s" >${PPKGDIR}/.started

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

  return 0
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

  return 0
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
