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

  echo "$BUILDTAG" | grep -q -e "freenas" -e "truenas"
  if [ $? -eq 0 ] ; then
    TBUILDDIR="${MASTERWRKDIR}/freenas"
  else
    echo "$BUILDTAG" | grep -q "trueos"
    if [ $? -eq 0 ] ; then
      TBUILDDIR="${MASTERWRKDIR}/trueos"
    else
      TBUILDDIR="${MASTERWRKDIR}/pcbsd"
    fi
  fi

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

jenkins_publish_pkg()
{
  if [ ! -d "${SFTPFINALDIR}/pkg/${TARGETREL}" ] ; then
    echo "Missing packages to push!"
    exit 1
  fi

  # Set target locations
  scale="pcbsd@pcbsd-master.scaleengine.net"
  target="/usr/home/pcbsd/mirror/pkg"

  # Make sure remote target exists
  echo "ssh ${scale} mkdir -p ${target}/${TARGETREL}"
  ssh ${scale} "mkdir -p ${target}/${TARGETREL}" >/dev/null 2>/dev/null

  # Copy packages
  rsync -va --delete-delay --delay-updates -e 'ssh' ${SFTPFINALDIR}/pkg/${TARGETREL}/ ${scale}:${target}/${TARGETREL}/
  if [ $? -ne 0 ] ; then exit_clean; fi

}

jenkins_publish_iso()
{
  if [ ! -d "${SFTPFINALDIR}/iso/${TARGETREL}" ] ; then
    echo "Missing iso to push!"
    exit 1
  fi

  # Set the targets
  scale="pcbsd@pcbsd-master.scaleengine.net"
  target="/usr/home/pcbsd/mirror/iso"
  ssh ${scale} "mkdir -p ${target}/${TARGETREL}/${ARCH}" >/dev/null 2>/dev/null

  # Copy the ISOs
  rsync -va --delete-delay --delay-updates -e 'ssh' ${SFTPFINALDIR}/iso/${TARGETREL}/${ARCH}/ ${scale}:${target}/${TARGETREL}/${ARCH}/
  if [ $? -ne 0 ] ; then exit_clean; fi
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

jenkins_freenas_push_docs()
{
  # Now lets upload the docs
  if [ -n "$SFTPHOST" ] ; then
    rm -rf /tmp/handbookpush 2>/dev/null
    mkdir -p /tmp/handbookpush

    # Get the docs from the staging server
    rsync -va --delete-delay --delay-updates -e 'ssh' ${SFTPUSER}@${SFTPHOST}:${DOCSTAGE}/handbook/ /tmp/handbookpush
    if [ $? -ne 0 ] ; then exit_clean; fi

    cd /tmp/handbookpush
    if [ $? -ne 0 ] ; then exit_clean ; fi

    # Make them live!
    rsync -a -v -z --delete --exclude "truenas*" -e 'ssh -i /root/.ssh/id_dsa.jenkins' . jenkins@api.freenas.org:/tank/doc/userguide/html
    if [ $? -ne 0 ] ; then exit_clean; fi
    rm -rf /tmp/handbookpush 2>/dev/null
  fi

  return 0
}

jenkins_freenas_push_api()
{
  # Now lets upload the docs
  if [ -n "$SFTPHOST" ] ; then
    rm -rf /tmp/apipush 2>/dev/null
    mkdir -p /tmp/apipush

    # Get the docs from the staging server
    rsync -va --delete-delay --delay-updates -e 'ssh' ${SFTPUSER}@${SFTPHOST}:${DOCSTAGE}/api/ /tmp/apipush
    if [ $? -ne 0 ] ; then exit_clean; fi

    cd /tmp/apipush
    if [ $? -ne 0 ] ; then exit_clean ; fi

    # Make them live!
    rsync -a -v -z --delete --exclude "truenas*" -e 'ssh -i /root/.ssh/id_dsa.jenkins' . jenkins@api.freenas.org:/tank/api/html
    if [ $? -ne 0 ] ; then exit_clean; fi

    rm -rf /tmp/apipush 2>/dev/null
  fi

  return 0
}

jenkins_freenas_push_nightly()
{
  # Sanity check that the build was done on this node
  if [ ! -d "${FNASBDIR}" ] ; then
    echo "ERROR: No such build dir: ${FNASBDIR}"
    exit 1
  fi

  cd ${FNASBDIR}
  if [ $? -ne 0 ] ; then exit_clean ; fi

  # Push the release to download.freenas.org
  make release-push ${BUILDOPTS}
  if [ $? -ne 0 ] ; then exit_clean ; fi

  return 0
}

jenkins_freenas_docs()
{
  if [ ! -d "/tmp/build" ] ; then
     mkdir /tmp/build
  fi

  DDIR=`mktemp -d /tmp/build/XXXX` 

  git clone --depth=1 https://github.com/freenas/freenas-docs ${DDIR}
  if [ $? -ne 0 ] ; then rm -rf ${DDIR} ; exit 1 ; fi

  cd ${DDIR}/userguide
  if [ $? -ne 0 ] ; then rm -rf ${DDIR} ; exit 1 ; fi

  make html
  if [ $? -ne 0 ] ; then rm -rf ${DDIR} ; exit 1 ; fi

  # Now lets sync the docs
  if [ -n "$SFTPHOST" ] ; then
    cd ${DDIR}/userguide/_build/html/
    if [ $? -ne 0 ] ; then exit_clean ; fi

    ssh ${SFTPUSER}@${SFTPHOST} "mkdir -p ${DOCSTAGE}/handbook" >/dev/null 2>/dev/null
    rsync -va --delete-delay --delay-updates -e 'ssh' . ${SFTPUSER}@${SFTPHOST}:${DOCSTAGE}/handbook
    if [ $? -ne 0 ] ; then exit_clean; fi
  fi

  rm -rf ${DDIR}

  return 0
}

jenkins_freenas_api()
{
  if [ ! -d "/tmp/build" ] ; then
     mkdir /tmp/build
  fi

  DDIR=`mktemp -d /tmp/build/XXXX` 

  git clone --depth=1 https://github.com/freenas/freenas ${DDIR}
  if [ $? -ne 0 ] ; then rm -rf ${DDIR} ; exit 1 ; fi

  cd ${DDIR}/docs/api
  if [ $? -ne 0 ] ; then rm -rf ${DDIR} ; exit 1 ; fi

  make html
  if [ $? -ne 0 ] ; then rm -rf ${DDIR} ; exit 1 ; fi

  # Now lets sync the api docs
  if [ -n "$SFTPHOST" ] ; then
    cd ${DDIR}/docs/api/_build/html/
    if [ $? -ne 0 ] ; then exit_clean ; fi

    ssh ${SFTPUSER}@${SFTPHOST} "mkdir -p ${DOCSTAGE}/api" >/dev/null 2>/dev/null
    rsync -va --delete-delay --delay-updates -e 'ssh' . ${SFTPUSER}@${SFTPHOST}:${DOCSTAGE}/api
    if [ $? -ne 0 ] ; then exit_clean; fi
  fi

  cleanup_workdir

  return 0
}

jenkins_trueos_docs()
{
  if [ ! -d "/tmp/build" ] ; then
     mkdir /tmp/build
  fi

  DDIR=`mktemp -d /tmp/build/XXXX` 

  git clone --depth=1 https://github.com/trueos/trueos-docs ${DDIR}
  if [ $? -ne 0 ] ; then rm -rf ${DDIR} ; exit 1 ; fi

  cd ${DDIR}/trueos-handbook
  if [ $? -ne 0 ] ; then rm -rf ${DDIR} ; exit 1 ; fi

  make html
  if [ $? -ne 0 ] ; then rm -rf ${DDIR} ; exit 1 ; fi

  # Now lets sync the TrueOS docs
  if [ -n "$SFTPHOST" ] ; then
    cd ${DDIR}/trueos-handbook/_build/html/
    if [ $? -ne 0 ] ; then exit_clean ; fi

    ssh ${SFTPUSER}@${SFTPHOST} "mkdir -p ${DOCSTAGE}/trueos-docs" >/dev/null 2>/dev/null
    rsync -va --delete-delay --delay-updates -e 'ssh' . ${SFTPUSER}@${SFTPHOST}:${DOCSTAGE}/trueos-docs
    if [ $? -ne 0 ] ; then exit_clean; fi
  fi

  cleanup_workdir
  return 0
}

jenkins_trueos_lumina_docs()
{
  if [ ! -d "/tmp/build" ] ; then
     mkdir /tmp/build
  fi

  DDIR=`mktemp -d /tmp/build/XXXX` 

  git clone --depth=1 https://github.com/trueos/lumina-docs ${DDIR}
  if [ $? -ne 0 ] ; then rm -rf ${DDIR} ; exit 1 ; fi

  cd ${DDIR}
  if [ $? -ne 0 ] ; then rm -rf ${DDIR} ; exit 1 ; fi

  make html
  if [ $? -ne 0 ] ; then rm -rf ${DDIR} ; exit 1 ; fi

  # Now lets sync the Lumina docs
  if [ -n "$SFTPHOST" ] ; then
    cd ${DDIR}/_build/html/
    if [ $? -ne 0 ] ; then exit_clean ; fi

    ssh ${SFTPUSER}@${SFTPHOST} "mkdir -p ${DOCSTAGE}/lumina-docs" >/dev/null 2>/dev/null
    rsync -va --delete-delay --delay-updates -e 'ssh' . ${SFTPUSER}@${SFTPHOST}:${DOCSTAGE}/lumina-docs
    if [ $? -ne 0 ] ; then exit_clean; fi
  fi

  cleanup_workdir
  return 0
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

  echo "$TYPE" | grep -q "freenas"
  if [ $? -eq 0 ] ; then
    BRANCH="production"
    . freenas.cfg
  else
    if [ -z "$BRANCH" ] ; then
      BRANCH="production"
    fi
    if [ -e 'trueos.cfg' ] ; then
      . trueos.cfg
    else
      . pcbsd.cfg
    fi
  fi

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
  if [ "$ARCH" = "i386" ] ; then PBUILD="${PBUILD}-i386"; fi
  PJAILNAME="`echo $JAILVER | sed 's|\.||g'`"
  echo "$TYPE" | grep -q trueos
  if [ $? -eq 0 ] ; then
    PBUILD="trueos-`echo $JAILVER | sed 's|\.||g'`"
    PPKGDIR="/poud/data/packages/${PJAILNAME}-trueosports"
    PJPORTSDIR="/poud/ports/trueosports"
  else
    PBUILD="pcbsd-`echo $JAILVER | sed 's|\.||g'`"
    PPKGDIR="/poud/data/packages/${PJAILNAME}-pcbsdports"
    PJPORTSDIR="/poud/ports/pcbsdports"
  fi
  export PBUILD PJPORTSDIR PPKGDIR

  # Set all the stage / work dirs
  if [ "$BRANCH" = "PRODUCTION" -o "$BRANCH" = "production" ] ; then
    PKGSTAGE="${SFTPFINALDIR}/pkg/${PKGVERUPLOAD}/amd64"
    ISOSTAGE="${SFTPFINALDIR}/iso/${TARGETREL}/amd64"
    DOCSTAGE="${SFTPFINALDIR}/doc/${TARGETREL}"
    WORKPKG="${SFTPWORKDIR}/pkg/${PKGVERUPLOAD}/amd64"
    WORKWORLD="${SFTPWORKDIR}/world/${WORLDTREL}/amd64"
  elif [ "$BRANCH" = "EDGE" -o "$BRANCH" = "edge" ] ; then
    PKGSTAGE="${SFTPFINALDIR}/pkg/${PKGVERUPLOAD}/edge/amd64"
    ISOSTAGE="${SFTPFINALDIR}/iso/${TARGETREL}/edge/amd64"
    DOCSTAGE="${SFTPFINALDIR}/doc/${TARGETREL}/edge"
    WORKPKG="${SFTPWORKDIR}/pkg/${PKGVERUPLOAD}/edge/amd64"
    WORKWORLD="${SFTPWORKDIR}/world/${WORLDTREL}/amd64"
  elif [ "$BRANCH" = "ENTERPRISE" -o "$BRANCH" = "enterprise" ] ; then
    PKGSTAGE="${SFTPFINALDIR}/pkg/${PKGVERUPLOAD}/enterprise/amd64"
    ISOSTAGE="${SFTPFINALDIR}/iso/${TARGETREL}/enterprise/amd64"
    DOCSTAGE="${SFTPFINALDIR}/doc/${TARGETREL}/enterprise"
    WORKPKG="${SFTPWORKDIR}/pkg/${PKGVERUPLOAD}/enterprise/amd64"
    WORKWORLD="${SFTPWORKDIR}/world/${WORLDTREL}/amd64"
  else
    echo "Invalid BRANCH"
    exit_clean
  fi
fi

