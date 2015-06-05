#!/bin/sh

# Where is the pcbsd-build program installed
PROGDIR="`realpath | sed 's|/scripts||g'`" ; export PROGDIR

# Source the config file
. ${PROGDIR}/freenas.cfg

cd ${PROGDIR}/scripts

# Source our functions
. ${PROGDIR}/scripts/functions.sh

# Make sure we have our freenas sources
if [ ! -d "${FNASSRC}" ]; then 
   rc_nohalt "rm -rf /tmp/fnasb"
   rc_nohalt "chflags -R noschg /tmp/fnasb"
   rc_nohalt "rm -rf /tmp/fnasb"
   rc_nohalt "mkdir `dirname ${FNASSRC}`"
   rc_halt "git clone --depth=1 ${GITFNASURL} /tmp/fnasb"
   rc_halt "ln -s /tmp/fnasb ${FNASSRC}"
   git_fnas_up "${FNASSRC}" "${FNASSRC}"
else
  if [ -d "${GITBRANCH}/.git" ]; then 
    echo "Updating FreeNAS sources..."
    git_fnas_up "${FNASSRC}" "${FNASSRC}"
  fi
fi

# Now create the world / kernel / distribution
cd ${FNASSRC}
rc_halt "make git-external"
rc_halt "make checkout"

# Ugly back to get freenas 9.x to build on CURRENT
if [ -n "$FREENASLEGACY" ] ; then
   sed -i '' "s|mtree -deU|${PROGDIR}/scripts/mtree -deU|g" ${FNASSRC}/FreeBSD/src/Makefile.inc1
   sed -i '' "s|mtree -deU|${PROGDIR}/scripts/mtree -deU|g" ${FNASSRC}/FreeBSD/src/release/Makefile.sysinstall
   sed -i '' "s|mtree -deU|${PROGDIR}/scripts/mtree -deU|g" ${FNASSRC}/FreeBSD/src/release/picobsd/build/picobsd
   sed -i '' "s|mtree -deU|${PROGDIR}/scripts/mtree -deU|g" ${FNASSRC}/FreeBSD/src/tools/tools/tinybsd/tinybsd
   sed -i '' "s|mtree -deU|${PROGDIR}/scripts/mtree -deU|g" ${FNASSRC}/FreeBSD/src/share/examples/Makefile
   sed -i '' "s|mtree -deU|${PROGDIR}/scripts/mtree -deU|g" ${FNASSRC}/FreeBSD/src/include/Makefile
   sed -i '' "s|mtree -deU|${PROGDIR}/scripts/mtree -deU|g" ${FNASSRC}/FreeBSD/src/usr.sbin/sysinstall/install.c
fi

rc_halt "make release"
