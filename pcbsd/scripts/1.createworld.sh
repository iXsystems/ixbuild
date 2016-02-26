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
if [ -d "${WORLDSRC}" ]; then 
  rm -rf ${WORLDSRC}
  chflags -R noschg ${WORLDSRC} >/dev/null 2>/dev/null
  rm -rf ${WORLDSRC} >/dev/null 2>/dev/null
fi
mkdir -p ${WORLDSRC}
rc_halt "git clone --depth=1 -b ${GITFBSDBRANCH} ${GITFBSDURL} ${WORLDSRC}"

# Now create the world / kernel / distribution
cd ${WORLDSRC}
MACHINE_ARCH="$REALARCH"
MACHINE="$REALARCH"
export MACHINE_ARCH MACHINE

# We only really need to go up to 8 CPUS for building world
CPUS=`sysctl -n kern.smp.cpus`
if [ "$CPUS" -gt 8 ] ; then
  CPUS=8
fi

make -j $CPUS buildworld TARGET=$ARCH
if [ $? -ne 0 ] ; then
   echo "Failed running: make buildworld TARGET=$ARCH"
   exit 1 
fi

# Make the standard kernel
make -j $CPUS buildkernel TARGET=$ARCH KERNCONF=${PCBSDKERN}
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

# Make src
#rm -rf ${PROGDIR}/tmp/usr >/dev/null 2>/dev/null
#mkdir -p ${PROGDIR}/tmp/usr
#ln -s ${WORLDSRC} ${PROGDIR}/tmp/usr/src
#rc_halt "tar cLvJf ${DISTDIR}/src.txz --exclude .git -C ${PROGDIR}/tmp ./usr"
#rm -rf ${PROGDIR}/tmp/usr >/dev/null 2>/dev/null

exit 0
