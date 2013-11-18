#!/bin/sh

# Where is the pcbsd-build program installed
PROGDIR="`realpath | sed 's|/scripts||g'`" ; export PROGDIR

# Source the config file
. ${PROGDIR}/pcbsd.cfg

cd ${PROGDIR}/scripts

# Source our functions
. ${PROGDIR}/scripts/functions.sh

# Added support for ZFS booting in boot/loader
LOADER_ZFS_SUPPORT="YES"
export LOADER_ZFS_SUPPORT

# Make sure we have our freebsd sources
if [ ! -d "${WORLDSRC}" ]; then 
   rc_halt "git clone ${GITFBSDURL} ${WORLDSRC}"
   git_fbsd_up "${WORLDSRC}" "${WORLDSRC}"
else
  if [ -d "${WORLDSRC}/.git" ]; then 
    echo "Updating FreeBSD sources..."
    git_fbsd_up "${WORLDSRC}" "${WORLDSRC}"
  fi
fi

# Now create the world / kernel / distribution
cd ${WORLDSRC}
MACHINE_ARCH="$REALARCH"
MACHINE="$REALARCH"
export MACHINE_ARCH MACHINE
make buildworld TARGET=$ARCH
if [ $? -ne 0 ] ; then
   echo "Failed running: make buildworld TARGET=$ARCH"
   exit 1 
fi

# Make the standard kernel
make buildkernel TARGET=$ARCH KERNCONF=${PCBSDKERN}
if [ $? -ne 0 ] ; then
   echo "Failed running: make buildkernel TARGET=$ARCH KERNCONF=${PCBSDKERN}"
   exit 1 
fi

# Create the FreeBSD Dist Files
mkdir ${DISTDIR} 2>/dev/null
rm ${DISTDIR}/*.txz 2>/dev/null
rm ${DISTDIR}/MANIFEST 2>/dev/null

# cd to release dir, and clean and make
cd ${WORLDSRC}/release
make clean

make ftp NOPORTS=yes NOSRC=yes TARGET=$ARCH
if [ $? -ne 0 ] ; then
   echo "Failed running: make ftp NOPORTS=yes NOSRC=yes TARGET=$ARCH"
   exit 1 
fi
rc_halt "mv ${WORLDSRC}/release/ftp/* ${DISTDIR}/"

# Cleanup old .txz files
cd ${WORLDSRC}/release
make clean

# Make src
rm -rf ${PROGDIR}/tmp/usr >/dev/null 2>/dev/null
mkdir -p ${PROGDIR}/tmp/usr
ln -s ${WORLDSRC} ${PROGDIR}/tmp/usr/src
rc_halt "tar cLvJf ${DISTDIR}/src.txz --exclude .git -C ${PROGDIR}/tmp ./usr"
rm -rf ${PROGDIR}/tmp/usr >/dev/null 2>/dev/null

exit 0
