#!/bin/sh

# Where is the pcbsd-build program installed
PROGDIR="`realpath | sed 's|/scripts||g'`" ; export PROGDIR

# Source the config file
. ${PROGDIR}/freenas.cfg

cd ${PROGDIR}/scripts

# Source our functions
. ${PROGDIR}/scripts/functions.sh

# Set local location of FreeNAS build
FNASBDIR="/freenas"
export FNASBDIR

# Check if grub2-efi is on the builder, remove it so
pkg info -q grub2-efi
if [ $? -eq 0 ] ; then
  pkg delete -y grub2-efi
fi

if [ -z "$BUILDTAG" ] ; then
  PREVEXT="previous"
else
  PREVEXT="$BUILDTAG"
fi

# Rotate an old build
if [ -d "${FNASBDIR}" ] ; then
  rc_nohalt "rm -rf ${FNASBDIR}.${PREVEXT}"
  rc_nohalt "chflags -R noschg ${FNASBDIR}.${PREVEXT}"
  rc_nohalt "rm -rf ${FNASBDIR}.${PREVEXT}"
  mv ${FNASBDIR} ${FNASBDIR}.${PREVEXT}
fi

# Make sure we have our freenas sources
if [ -d "${FNASSRC}" ]; then
  if [ -d "${GITBRANCH}/.git" ]; then 
    echo "Updating FreeNAS sources..."
    git_fnas_up "${FNASSRC}" "${FNASSRC}"
  fi
else
  rc_nohalt "mkdir `dirname ${FNASSRC}`"
  rc_halt "git clone --depth=1 -b ${GITFNASBRANCH} ${GITFNASURL} ${FNASBDIR}"
  rc_halt "ln -s ${FNASBDIR} ${FNASSRC}"
  git_fnas_up "${FNASSRC}" "${FNASSRC}"
fi

# Now create the world / kernel / distribution
cd ${FNASSRC}

if [ "$FREENASLEGACY" = "910" ] ; then
  PROFILEARGS="PROFILE=freenas9"
fi

rc_halt "make checkout ${PROFILEARGS}"

# Ugly hack to get freenas 9.x to build on CURRENT
if [ "$FREENASLEGACY" = "YES" ] ; then

   # Add all the fixes to use a 9.3 version of mtree
   sed -i '' "s|mtree -deU|${PROGDIR}/scripts/kludges/mtree -deU|g" ${FNASSRC}/FreeBSD/src/Makefile.inc1
   sed -i '' "s|mtree -deU|${PROGDIR}/scripts/kludges/mtree -deU|g" ${FNASSRC}/FreeBSD/src/release/Makefile.sysinstall
   sed -i '' "s|mtree -deU|${PROGDIR}/scripts/kludges/mtree -deU|g" ${FNASSRC}/FreeBSD/src/release/picobsd/build/picobsd
   sed -i '' "s|mtree -deU|${PROGDIR}/scripts/kludges/mtree -deU|g" ${FNASSRC}/FreeBSD/src/tools/tools/tinybsd/tinybsd
   sed -i '' "s|mtree -deU|${PROGDIR}/scripts/kludges/mtree -deU|g" ${FNASSRC}/FreeBSD/src/share/examples/Makefile
   sed -i '' "s|mtree -deU|${PROGDIR}/scripts/kludges/mtree -deU|g" ${FNASSRC}/FreeBSD/src/include/Makefile
   sed -i '' "s|mtree -deU|${PROGDIR}/scripts/kludges/mtree -deU|g" ${FNASSRC}/FreeBSD/src/usr.sbin/sysinstall/install.c
   MTREE_CMD="${PROGDIR}/scripts/kludges/mtree"
   export MTREE_CMD

   if [ ! -e "/usr/bin/makeinfo" ] ; then
      cp ${PROGDIR}/scripts/kludges/makeinfo /usr/bin/makeinfo
      chmod 755 /usr/bin/makeinfo
   fi
   if [ ! -e "/usr/bin/mklocale" ] ; then
      cp ${PROGDIR}/scripts/kludges/mklocale /usr/bin/mklocale
      chmod 755 /usr/bin/mklocale
   fi
   if [ ! -e "/usr/bin/install-info" ] ; then
      cp ${PROGDIR}/scripts/kludges/install-info /usr/bin/install-info
      chmod 755 /usr/bin/install-info
   fi

   # Copy our kludged build_jail.sh
   cp ${PROGDIR}/scripts/kludges/build_jail.sh ${FNASSRC}/build/build_jail.sh

   # NANO_WORLDDIR expects this to exist
   if [ ! -d "/var/home" ] ; then
      mkdir /var/home
   fi

   # Fix a missing directory in NANO_WORLDDIR
   sed -i '' 's|geom_gate.ko|geom_gate.ko;mkdir -p ${NANO_WORLDDIR}/usr/src/sys|g' ${FNASSRC}/build/nanobsd-cfg/os-base-functions.sh
fi

if [ -e "pipelog" ] ; then
  rm pipelog
fi
mkfifo pipelog
tee ${FNASSRC}/.auto-log < pipelog &
make release ${PROFILEARGS} >pipelog 2>pipelog
if [ $? -ne 0 ] ; then

  # Try to provide some context to the failure right in the summary e-mail
  grep -m 1 -C 8 "Error code" ${FNASSRC}/.auto-log

  rm ${FNASSRC}/.auto-log
  rm pipelog
  echo "ERROR: Failed running 'make release'"
  exit 1
fi

rm pipelog
exit 0
