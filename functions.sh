#!/bin/sh

# Set the repo we pull for build / tests
GITREPO="https://github.com/iXsystems/ixbuild.git"
# Set the branch to use for above repo
if [ -z "$IXBUILDBRANCH" ] ; then
  IXBUILDBRANCH="master"
fi

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
    rm -rf ${MASTERWRKDIR} 2>/dev/null
    chflags -R noschg ${MASTERWRKDIR} 2>/dev/null
    rm -rf ${MASTERWRKDIR}
  fi
  cd
}

exit_clean()
{
  cleanup_workdir
  exit 1
}

create_workdir()
{
  if [ ! -d "/tmp/build" ] ; then
     mkdir /tmp/build
  fi
  cd /tmp/build

  MASTERWRKDIR=`mktemp -d /tmp/build/XXXX` 

  cocmd="git clone --depth=1 -b ${IXBUILDBRANCH} ${GITREPO} ${MASTERWRKDIR}"
  echo "Cloning with: $cocmd"
  $cocmd
  if [ $? -ne 0 ] ; then exit_clean; fi

  cd ${MASTERWRKDIR}
  if [ $? -ne 0 ] ; then exit_clean; fi

  # Copy over user builds
  if [ -d "/ixbuild/builds" ] ; then
    rm -rf ${MASTERWRKDIR}/builds
    cp -r /ixbuild/builds ${MASTERWRKDIR}/builds
  fi

  case $TYPE in
    freenas|freenas-tests|freenas-ltest|freenas-lupgrade|freenas-combo) TBUILDDIR="${MASTERWRKDIR}/freenas" ;;
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
  if [ -z "$SFTPHOST" ] ; then return 0; fi

  ssh ${SFTPUSER}@${SFTPHOST} "mkdir -p ${WORKPKG}" >/dev/null 2>/dev/null

  echo "Pushing cached pkgs..."
  rsync -va --delete-delay --delay-updates -e 'ssh' . ${SFTPUSER}@${SFTPHOST}:${WORKPKG}/ >${MASTERWRKDIR}/push.log 2>${MASTERWRKDIR}/push.log
  if [ $? -ne 0 ] ; then tail -50 ${MASTERWRKDIR}/push.log ; exit_clean; fi
}


pull_pkgworkdir()
{
  if [ -z "$SFTPHOST" ] ; then return 0; fi

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

  # Pushing to a local directory?
  if [ -z "$SFTPHOST" ] ; then
    if [ ! -d "${PCBSDBDIR}/fbsd-dist/${WORLDTREL}" ] ; then mkdir -p ${PCBSDBDIR}/fbsd-dist/${WORLDTREL}; fi
    rm ${PCBSDBDIR}/fbsd-dist/${WORLDTREL}/* 2>/dev/null
    echo "Saving FreeBSD dist files -> ${PCBSDBDIR}/fbsd-dist/${WORLDTREL}"
    cp * ${PCBSDBDIR}/fbsd-dist/${WORLDTREL}/
    return 0
  fi

  # Push world packages to work directory
  ssh ${SFTPUSER}@${SFTPHOST} "mkdir -p ${WORKWORLD}" >/dev/null 2>/dev/null

  rsync -va --delete-delay --delay-updates -e 'ssh' . ${SFTPUSER}@${SFTPHOST}:${WORKWORLD}/ >${MASTERWRKDIR}/push.log 2>${MASTERWRKDIR}/push.log
  if [ $? -ne 0 ] ; then tail -50 ${MASTERWRKDIR}/push.log ; exit_clean; fi

  if [ -n "$PKGBASE" ] ; then
    # Push packages to base directory
    cd ${TBUILDDIR}/fbsd-pkg
    ssh ${SFTPUSER}@${SFTPHOST} "mkdir -p ${PKGSTAGE}-base" >/dev/null 2>/dev/null
    rsync -va --delete-delay --delay-updates -e 'ssh' . ${SFTPUSER}@${SFTPHOST}:${PKGSTAGE}-base/ >${MASTERWRKDIR}/push.log 2>${MASTERWRKDIR}/push.log
  fi

  # Dist files to dist directory
  cd ${TBUILDDIR}/fbsd-dist
  ssh ${SFTPUSER}@${SFTPHOST} "mkdir -p ${ISOSTAGE}/dist" >/dev/null 2>/dev/null
  rsync -va --delete-delay --delay-updates -e 'ssh' . ${SFTPUSER}@${SFTPHOST}:${ISOSTAGE}/dist/ >${MASTERWRKDIR}/push.log 2>${MASTERWRKDIR}/push.log
}

pull_world()
{
  if [ ! -d "${TBUILDDIR}/fbsd-dist" ] ; then
    mkdir -p ${TBUILDDIR}/fbsd-dist
  fi

  # Pulling from a local dist set
  if [ -z "$SFTPHOST" ] ; then
    if [ ! -d "${PCBSDBDIR}/fbsd-dist/${WORLDTREL}" ] ; then return 1; fi
    cp ${PCBSDBDIR}/fbsd-dist/${WORLDTREL}/* ${TBUILDDIR}/fbsd-dist/
    if [ $? -ne 0 ] ; then
      return 1
    fi
    return 0
  fi

  # Pulling from a remote dist set

  # Check if the world exists
  ssh ${SFTPUSER}@${SFTPHOST} "ls ${WORKWORLD}" >/dev/null 2>/dev/null
  if [ $? -ne 0 ] ; then
     return 1
  fi

  if [ -n "$PKGBASE" ] ; then
    # Push packages to base directory
    mkdir ${TBUILDDIR}/fbsd-pkg
    cd ${TBUILDDIR}/fbsd-pkg
    if [ $? -ne 0 ] ; then exit_clean; fi
    echo "Pulling base packages..."
    rsync -va --delete-delay --delay-updates -e 'ssh' ${SFTPUSER}@${SFTPHOST}:${PKGSTAGE}-base/ . >${MASTERWRKDIR}/push.log 2>${MASTERWRKDIR}/push.log
  fi

  cd ${TBUILDDIR}/fbsd-dist
  if [ $? -ne 0 ] ; then exit_clean; fi

  rsync -va --delete-delay --delay-updates -e 'ssh' ${SFTPUSER}@${SFTPHOST}:${WORKWORLD}/ . >${MASTERWRKDIR}/push.log 2>${MASTERWRKDIR}/push.log
  if [ $? -ne 0 ] ; then tail -50 ${MASTERWRKDIR}/push.log ; exit_clean; fi
  return 0
}

pull_iso()
{
  if [ -z "$SFTPHOST" ] ; then return 0; fi

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
  if [ -n "$SFTPHOST" ] ; then
    remotetime=`ssh ${SFTPUSER}@${SFTPHOST} "cat ${PKGSTAGE}/.started" 2>/dev/null`
    localtime=`cat ${PPKGDIR}/.started 2>/dev/null`
    if [ -n "$remotetime" -a -n "$localtime" ] ; then
      if [ $remotetime -lt $localtime ] ; then
        push_pkgworkdir
      fi
    fi
  fi

  cd ${TBUILDDIR}
  make ports-update-all
  if [ $? -ne 0 ] ; then exit_clean; fi

  # Pull the workdir from the cache
  pull_pkgworkdir

  cd ${TBUILDDIR}
  if [ $? -ne 0 ] ; then exit_clean; fi

  # Save the timestamp of when we started this poud run
  if [ ! -d "${PPKGDIR}" ] ; then mkdir -p ${PPKGDIR} ; fi
  date +"%s" >${PPKGDIR}/.started

  # Make the release or ISO packages
  if [ "$1" = "release" ] ; then
    make ports
    if [ $? -ne 0 ] ; then push_pkgworkdir; exit_clean; fi
  else
    make iso-ports
    if [ $? -ne 0 ] ; then push_pkgworkdir; exit_clean; fi
  fi

  # Push over the workdir to the cache
  push_pkgworkdir

  # Yay, success! Lets rsync the package set to staging machine
  cd $PPKGDIR
  if [ $? -ne 0 ] ; then exit_clean; fi

  if [ -n "$SFTPHOST" ] ; then
    ssh ${SFTPUSER}@${SFTPHOST} "mkdir -p ${PKGSTAGE}" >/dev/null 2>/dev/null

    rsync -va --delete-delay --delay-updates -e 'ssh' . ${SFTPUSER}@${SFTPHOST}:${PKGSTAGE} >${MASTERWRKDIR}/push.log 2>${MASTERWRKDIR}/push.log
    if [ $? -ne 0 ] ; then tail -50 ${MASTERWRKDIR}/push.log ; exit_clean; fi
  fi

  cleanup_workdir

  exit 0
}

jenkins_iso()
{
  create_workdir

  pull_world

  # Pull the workdir from the cache
  pull_pkgworkdir

  cd ${TBUILDDIR}
  if [ $? -ne 0 ] ; then exit_clean; fi

  make image
  if [ $? -ne 0 ] ; then exit_clean; fi

  # Now lets sync the ISOs
  cd ${TBUILDDIR}/iso
  if [ $? -ne 0 ] ; then exit_clean; fi

  if [ -n "$SFTPHOST" ] ; then
    ssh ${SFTPUSER}@${SFTPHOST} "mkdir -p ${ISOSTAGE}" >/dev/null 2>/dev/null
    rsync -va --delete-delay --delay-updates -e 'ssh' . ${SFTPUSER}@${SFTPHOST}:${ISOSTAGE} >${MASTERWRKDIR}/push.log 2>${MASTERWRKDIR}/push.log
    if [ $? -ne 0 ] ; then tail -50 ${MASTERWRKDIR}/push.log ; exit_clean; fi
  fi

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

  if [ -n "$SFTPHOST" ] ; then
    ssh ${SFTPUSER}@${SFTPHOST} "mkdir -p ${ISOSTAGE}" >/dev/null 2>/dev/null
    rsync -va --delete-delay --delay-updates -e 'ssh' . ${SFTPUSER}@${SFTPHOST}:${ISOSTAGE}
    if [ $? -ne 0 ] ; then exit_clean; fi
  fi

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
  if [ -n "$SFTPHOST" ] ; then
    if [ "$FREENASLEGACY" = "YES" ] ; then
      cd ${FNASBDIR}/objs
      if [ $? -ne 0 ] ; then exit_clean ; fi
      rm -rf os-base
    else
      cd ${FNASBDIR}/_BE/release/
      if [ $? -ne 0 ] ; then exit_clean ; fi
    fi

    ssh ${SFTPUSER}@${SFTPHOST} "mkdir -p ${ISOSTAGE}" >/dev/null 2>/dev/null
    rsync -va --delete-delay --delay-updates -e 'ssh' . ${SFTPUSER}@${SFTPHOST}:${ISOSTAGE}
    if [ $? -ne 0 ] ; then exit_clean; fi
  fi

  cleanup_workdir

  return 0
}

jenkins_freenas_live_upgrade()
{
  create_workdir

  if [ -z "$LIVEHOST" ] ; then echo "Missing LIVEHOST!" ; exit_clean ; fi
  if [ -z "$LIVEUSER" ] ; then echo "Missing LIVEUSER!" ; exit_clean ; fi
  if [ -z "$LIVEPASS" ] ; then echo "Missing LIVEPASS!" ; exit_clean ; fi

  cd ${TBUILDDIR}
  make liveupgrade
  if [ $? -ne 0 ] ; then exit_clean ; fi

  cleanup_workdir

  return 0
}

jenkins_freenas_live_tests()
{
  create_workdir

  if [ -z "$LIVEHOST" ] ; then echo "Missing LIVEHOST!" ; exit_clean ; fi
  if [ -z "$LIVEUSER" ] ; then echo "Missing LIVEUSER!" ; exit_clean ; fi
  if [ -z "$LIVEPASS" ] ; then echo "Missing LIVEPASS!" ; exit_clean ; fi

  cd ${TBUILDDIR}
  make livetests
  if [ $? -ne 0 ] ; then exit_clean ; fi

  cleanup_workdir

  return 0
}


jenkins_freenas_tests()
{
  create_workdir

  cd ${TBUILDDIR}
  if [ $? -ne 0 ] ; then exit_clean ; fi

  if [ -n "$SFTPHOST" ] ; then
    # Now lets sync the ISOs
    if [ -d "${FNASBDIR}/_BE/release" ] ; then
      rm -rf ${FNASBDIR}/_BE/release
    fi

    mkdir -p ${FNASBDIR}/_BE/release
    cd ${FNASBDIR}/_BE/release
    if [ $? -ne 0 ] ; then exit_clean; fi

    ssh ${SFTPUSER}@${SFTPHOST} "mkdir -p ${ISOSTAGE}" >/dev/null 2>/dev/null
    rsync -va --delete-delay --delay-updates -e 'ssh' ${SFTPUSER}@${SFTPHOST}:${ISOSTAGE} ${FNASBDIR}/_BE/release/
    if [ $? -ne 0 ] ; then exit_clean ; fi
  fi

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

# Set the builds directory
BDIR="./builds"
export BDIR

# Set location of local PC-BSD build data
PCBSDBDIR="/pcbsd"
export PCBSDBDIR

# Set the build tag
BUILDTAG="$BUILD"
export BUILDTAG

# Set location of local FreeNAS build data
FNASBDIR="/$BUILDTAG"
export FNASBDIR

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
    freenas-ltest|freenas-lupgrade)
       BRANCH="production"
       . freenas.cfg
       if [ -e "freenas-ltest.cfg" ] ; then
         echo "Using `pwd`/freenas-ltest.cfg for Live Test host configuration"
         . freenas-ltest.cfg
       fi
       if [ -z "$LIVEHOST" -o -z "$LIVEUSER" -o -z "$LIVEPASS" ] ; then
         echo "Missing Live Test host settings! LIVEHOST/LIVEUSER/LIVEPASS"
         exit_clean
       fi
       ;;
    *)
       if [ -z "$BRANCH" ] ; then
         BRANCH="production"
       fi
       . pcbsd.cfg
       ;;
  esac


  # Set the variables to reference poudrire jail locations
  if [ -z "$JAILVER" ] ; then
    JAILVER="$TARGETREL"
  fi
  case $TYPE in
    jail|pkg) WORLDTREL="$JAILVER" ;;
     *) WORLDTREL="$TARGETREL" ;;
  esac
  if [ -z "$PKGVERUPLOAD" ] ; then
    PKGVERUPLOAD="$WORLDTREL"
  fi

  # Poudriere variables
  PBUILD="pcbsd-`echo $JAILVER | sed 's|\.||g'`"
  if [ "$ARCH" = "i386" ] ; then PBUILD="${PBUILD}-i386"; fi
  PJAILNAME="`echo $JAILVER | sed 's|\.||g'`"
  PPKGDIR="/poud/data/packages/${PJAILNAME}-pcbsdports"
  PJPORTSDIR="/poud/ports/pcbsdports"
  export PBUILD PJPORTSDIR PPKGDIR

  # Set all the stage / work dirs
  if [ "$BRANCH" = "PRODUCTION" -o "$BRANCH" = "production" ] ; then
    PKGSTAGE="${SFTPFINALDIR}/pkg/${PKGVERUPLOAD}/amd64"
    ISOSTAGE="${SFTPFINALDIR}/iso/${TARGETREL}/amd64"
    WORKPKG="${SFTPWORKDIR}/pkg/${PKGVERUPLOAD}/amd64"
    WORKWORLD="${SFTPWORKDIR}/world/${WORLDTREL}/amd64"
  elif [ "$BRANCH" = "EDGE" -o "$BRANCH" = "edge" ] ; then
    PKGSTAGE="${SFTPFINALDIR}/pkg/${PKGVERUPLOAD}/edge/amd64"
    ISOSTAGE="${SFTPFINALDIR}/iso/${TARGETREL}/edge/amd64"
    WORKPKG="${SFTPWORKDIR}/pkg/${PKGVERUPLOAD}/edge/amd64"
    WORKWORLD="${SFTPWORKDIR}/world/${WORLDTREL}/amd64"
  elif [ "$BRANCH" = "ENTERPRISE" -o "$BRANCH" = "enterprise" ] ; then
    PKGSTAGE="${SFTPFINALDIR}/pkg/${PKGVERUPLOAD}/enterprise/amd64"
    ISOSTAGE="${SFTPFINALDIR}/iso/${TARGETREL}/enterprise/amd64"
    WORKPKG="${SFTPWORKDIR}/pkg/${PKGVERUPLOAD}/enterprise/amd64"
    WORKWORLD="${SFTPWORKDIR}/world/${WORLDTREL}/amd64"
  else
    echo "Invalid BRANCH"
    exit_clean
  fi
fi

