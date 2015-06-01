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
   rc_halt "git clone ${GITFNASURL} ${FNASSRC}"
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
