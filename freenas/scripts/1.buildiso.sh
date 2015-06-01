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
   rc_halt "git clone ${GITFNASURL} /tmp/fnasb"
   rc_halt "ln -s /tmp/fnasb ${FNASSRC}"
   git_fnas_up "${FNASSRC}" "${FNASSRC}"
else
  if [ -d "${GITBRANCH}/.git" ]; then 
    echo "Updating FreeBSD sources..."
    git_fnas_up "${FNASSRC}" "${FNASSRC}"
  fi
fi

# Now create the world / kernel / distribution
cd ${FNASSRC}
rc_halt "make git-external"
rc_halt "make checkout"
rc_halt "make release"
