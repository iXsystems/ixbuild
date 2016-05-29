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
  mkdir ${DISTDIR}/world 2>/dev/null

  # Manually create the dist-files
  cd ${WORLDSRC}
  make installworld DESTDIR=${DISTDIR}/world
  if [ $? -ne 0 ] ; then
     echo "Failed running: make installworld DESTDIR=$DISTDIR/world"
     exit 1
  fi

  make installkernel DESTDIR=${DISTDIR}/world
  if [ $? -ne 0 ] ; then
     echo "Failed running: make installkernel DESTDIR=$DISTDIR/world"
     exit 1
  fi

  make distribution DESTDIR=${DISTDIR}/world
  if [ $? -ne 0 ] ; then
     echo "Failed running: make distribution DESTDIR=$DISTDIR/world"
     exit 1
  fi

  # Create exclude list for base.txz
  cat << EOF >/tmp/.excList.$$
./boot/kernel
./usr/share/doc
./usr/lib32
./usr/bin/ldd32
./usr/libexec/ld-elf32.so.1
./usr/libexec/ld-elf32.so.1
EOF

  # Create base.txz
  tar cvJ -f ${DISTDIR}/base.txz -C ${DISTDIR}/world -X /tmp/.excList.$$ .
  if [ $? -ne 0 ] ; then
     echo "Failed creating base.txz"
     rm /tmp/.excList.$$
     exit 1
  fi
  rm /tmp/.excList.$$

  # Create kernel.txz
  tar cvJ -f ${DISTDIR}/kernel.txz -C ${DISTDIR}/world ./boot/kernel
  if [ $? -ne 0 ] ; then
     echo "Failed creating kernel.txz"
     exit 1
  fi

  # Create doc.txz
  tar cvJ -f ${DISTDIR}/doc.txz -C ${DISTDIR}/world ./usr/share/doc
  if [ $? -ne 0 ] ; then
     echo "Failed creating doc.txz"
     exit 1
  fi

  # Create lib32.txz
  tar cvJ -f ${DISTDIR}/lib32.txz -C ${DISTDIR}/world ./usr/lib32 ./usr/libexec/ld-elf32.so.1 ./usr/bin/ldd32 ./libexec/ld-elf32.so.1
  if [ $? -ne 0 ] ; then
     echo "Failed creating lib32.txz"
     exit 1
  fi

  # Cleanup
  rm -rf ${DISTDIR}/world 2>/dev/null
  chflags -R noschg ${DISTDIR}/world
  rm -rf ${DISTDIR}/world

  # Create the MANIFEST
  cd ${DISTDIR}
  echo "Creating MANIFEST"
  sh ${WORLDSRC}/release/scripts/make-manifest.sh *.txz > MANIFEST

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
