#!/usr/local/bin/bash

# Where is the pcbsd-build program installed
PROGDIR="`realpath | sed 's|/scripts$||g'`" ; export PROGDIR

# Source our functions
. ${PROGDIR}/scripts/functions.sh
. ${PROGDIR}/scripts/functions-tests.sh
. ${PROGDIR}/scripts/functions-vm.sh

# Source our resty / jsawk functions
. ${PROGDIR}/../utils/resty -W "http://${ip}:80/api/v1.0" -H "Accept: application/json" -H "Content-Type: application/json" -u ${fuser}:${fpass}

# Make sure we have all the required packages installed
${PROGDIR}/scripts/checkprogs.sh

if [ ! -d "${PROGDIR}/tmp" ] ; then
  mkdir ${PROGDIR}/tmp
fi

# Create ISO for VM
create_auto_install

# Determine which VM backend to start
if [ -n "$USE_BHYVE" ] ; then
  start_bhyve
else
  start_vbox
fi

# Run the REST tests now
clean_xml_results
set_ip
run_tests

# Determine which VM backend to stop
if [ -n "$USE_BHYVE" ] ; then
  stop_bhyve
else
  stop_vbox
fi
