#!/bin/sh

# Where is the build program installed
PROGDIR="`realpath | sed 's|/scripts||g'`" ; export PROGDIR

# Source the config file
. ${PROGDIR}/trueos.cfg

cd ${PROGDIR}/scripts

# Source our functions
. ${PROGDIR}/scripts/functions.sh

create_dist_files() {

  # Create the FreeBSD Dist Files
  if [ -n "${DISTDIR}" -a -d "${DISTDIR}" ] ; then
    rm -rf ${DISTDIR}
  fi
  mkdir ${DISTDIR} 2>/dev/null

 # cd to release dir, and clean and make
  cd ${WORLDSRC}/release
  make clean

  # Create the FTP files
  make ftp NOPORTS=yes TARGET=$ARCH
  if [ $? -ne 0 ] ; then
     echo "Failed running: make ftp NOPORTS=yes TARGET=$ARCH"
     exit 1
  fi
  rc_halt "mv ${WORLDSRC}/release/ftp/* ${DISTDIR}/"

  # Cleanup old .txz files
  cd ${WORLDSRC}/release
  make clean

  # Dirty dirty hack to get llvm38 into our base packages
  # specifically for buildign in poudriere
  rm -rf ${DISTDIR}/llvm-src 2>/dev/null
  chflags -R noschg ${DISTDIR}/llvm-src 2>/dev/null
  rm -rf ${DISTDIR}/llvm-src 2>/dev/null

  mkdir ${DISTDIR}/llvm-src
  tar xvpf ${DISTDIR}/base.txz -C ${DISTDIR}/llvm-src
  if [ $? -ne 0 ] ; then
     echo "Failed running: tar xvpf base.txz"
     exit 1
  fi

  pkg info -l llvm38 | tail -n +2 | awk '{print $1}' > /tmp/.llvmPlist

  echo "Extracting llvm38 to base"
  tar cvf - -T /tmp/.llvmPlist 2>/dev/null | tar xvpf - -C ${DISTDIR}/llvm-src

  tar cvJf ${DISTDIR}/base.txz -C ${DISTDIR}/llvm-src .
  if [ $? -ne 0 ] ; then
     echo "Failed running: tar cvJf base.txz"
     exit 1
  fi

  # Remove temp dir
  rm -rf ${DISTDIR}/llvm-src 2>/dev/null
  chflags -R noschg ${DISTDIR}/llvm-src 2>/dev/null
  rm -rf ${DISTDIR}/llvm-src 2>/dev/null

  # Re-run make-manifest
  cd ${DISTDIR}
  ${WORLDSRC}/release/scripts/make-manifest.sh *.txz > MANIFEST

  return 0
}

create_base_pkg_files()
{
  cd ${WORLDSRC}

  if [ -n "${PROGDIR}/fbsd-pkg" -a -d "${PROGDIR}/fbsd-pkg" ] ; then
    rm -rf ${PROGDIR}/fbsd-pkg
  fi
  mkdir ${PROGDIR}/fbsd-pkg 2>/dev/null

  # Unset some variables which may be getting in the way
  ODISTDIR="$DISTDIR"
  OWORLDSRC="$WORLDSRC"
  unset DISTDIR WORLDSRC

  # Create the package files now
  make packages
  if [ $? -ne 0 ] ; then
     env
     echo "Failed running: make packages"
     exit 1
  fi

  # Move the package files and prep them
  mv /usr/obj/usr/src/repo/*/latest/* ${PROGDIR}/fbsd-pkg/
  if [ $? -ne 0 ] ; then
     echo "Failed moving packages"
     exit 1
  fi

  # This is super ugly, remove it once they properly fix pkg
  # grab all the distrib files
  rc_halt "mkdir ${PROGDIR}/fbsd-distrib"
  cd /usr/src
  make distrib-dirs DESTDIR=${PROGDIR}/fbsd-distrib
  if [ $? -ne 0 ] ; then
     env
     echo "Failed running: make distrib-dirs"
     exit 1
  fi
  make distribution DESTDIR=${PROGDIR}/fbsd-distrib
  if [ $? -ne 0 ] ; then
     env
     echo "Failed running: make distribution"
     exit 1
  fi

  # Couple of files also missed by pkg base
  rc_halt "tar xvpf ${ODISTDIR}/base.txz -C ${PROGDIR}/fbsd-distrib ./usr/lib/libgcc_eh.a ./usr/lib/libgcc_eh_p.a"
  rc_halt "tar xvpf ${ODISTDIR}/base.txz -C ${PROGDIR}/fbsd-distrib ./usr/share/examples"
  rc_halt "tar xvpf ${ODISTDIR}/base.txz -C ${PROGDIR}/fbsd-distrib ./usr/share/calendar"
  rc_halt "tar xvpf ${ODISTDIR}/base.txz -C ${PROGDIR}/fbsd-distrib ./usr/share/tmac"
  rc_halt "tar xvpf ${ODISTDIR}/base.txz -C ${PROGDIR}/fbsd-distrib ./usr/include"

  # Signing script
  if [ -n "$PKGSIGNCMD" ] ; then
    echo "Signing base packages..."
    rc_halt "cd ${PROGDIR}/fbsd-pkg/"
    rc_halt "pkg repo . signing_command: ${PKGSIGNCMD}"
  fi

  rc_halt "tar cvJf ${PROGDIR}/fbsd-pkg/fbsd-distrib.txz -C ${PROGDIR}/fbsd-distrib ."
  rm -rf ${PROGDIR}/fbsd-distrib

  WORLDSRC="$OWORLDSRC"
  DISTDIR="$ODISTDIR"
  return 0
}

if [ -z "$DISTDIR" ] ; then
  DISTDIR="${PROGDIR}/fbsd-dist"
fi

# Ugly, but freebsd packages like to be built here for now
if [ -n "$PKGBASE" ] ; then
  WORLDSRC="/usr/src"
  rm -rf /usr/obj/usr/src/repo/ >/dev/null 2>/dev/null
fi

# Make sure we have our freebsd sources
if [ -d "${WORLDSRC}" ]; then 
  rm -rf ${WORLDSRC}
  chflags -R noschg ${WORLDSRC} >/dev/null 2>/dev/null
  rm -rf ${WORLDSRC} >/dev/null 2>/dev/null
fi
mkdir -p ${WORLDSRC}
rc_halt "git clone --depth=1 -b ${GITFBSDBRANCH} ${GITFBSDURL} ${WORLDSRC}"

# Now create the world / kernel / distribution
cd ${WORLDSRC}

CPUS=`sysctl -n kern.smp.cpus`

make -j $CPUS buildworld buildkernel
if [ $? -ne 0 ] ; then
   echo "Failed running: make buildworld buildkernel"
   exit 1 
fi

create_dist_files

if [ -n "$PKGBASE" ] ; then
  create_base_pkg_files
fi

exit 0
