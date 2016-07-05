#!/bin/sh
#        Author: Kris Moore
#   Description: Makes the DVD ISO
#     Copyright: 2008 PC-BSD Software / iXsystems
############################################################################

# Check if we have sourced the variables yet
if [ -z $PDESTDIR ]
then
  . ../trueos.cfg
fi

# Source our functions
. ${PROGDIR}/scripts/functions.sh

# All the dist files
rc_nohalt "rm -rf ${PROGDIR}/iso/dist"
rc_halt "mkdir ${PROGDIR}/iso/dist"
rc_halt "cp ${DISTDIR}/* ${PROGDIR}/iso/dist/"

exit 0
