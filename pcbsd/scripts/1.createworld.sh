#!/bin/sh

# Where is the pcbsd-build program installed
PROGDIR="`realpath | sed 's|/scripts||g'`" ; export PROGDIR

# Source the config file
. ${PROGDIR}/pcbsd.cfg

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

  # Create the CD images
  rm -rf ${PROGDIR}/fbsd-iso >/dev/null 2>/dev/null
  mkdir ${PROGDIR}/fbsd-iso
  make cdrom
  if [ $? -ne 0 ] ; then
     echo "Failed running: make cdrom"
     exit 1
  fi
  mv *.iso ${PROGDIR}/fbsd-iso

  # Cleanup old .txz files
  cd ${WORLDSRC}/release
  make clean

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
  rc_halt "make distrib-dirs DESTDIR=${PROGDIR}/fbsd-distrib"
  rc_halt "make distribution DESTDIR=${PROGDIR}/fbsd-distrib"

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

# We only really need to go up to 8 CPUS for building world
CPUS=`sysctl -n kern.smp.cpus`
if [ "$CPUS" -gt 8 ] ; then
  CPUS=8
fi

make -j $CPUS buildworld buildkernel
if [ $? -ne 0 ] ; then
   echo "Failed running: make buildworld buildkernel"
   exit 1 
fi

if [ -n "$PKGBASE" ] ; then
  create_base_pkg_files
fi
create_dist_files

exit 0
