#!/usr/local/bin/bash

# Source our functions
. ${PROGDIR}/scripts/functions.sh
. ${PROGDIR}/scripts/functions-tests.sh
. ${PROGDIR}/scripts/functions-vm.sh

# Source our resty / jsawk functions
. ${PROGDIR}/../utils/resty -W "http://${ip}:80/api/v1.0" -H "Accept: application/json" -H "Content-Type: application/json" -u ${fuser}:${fpass}

# Make sure we have all the required packages installed
${PROGDIR}/scripts/checkprogs.sh

# Create ISO for VM
create_auto_install

# Determine which VM backend to start
if [ -n "$USE_BHYVE" ] ; then
  start_bhyve
else
  start_vbox
fi

# Cleanup old test results before running tests
clean_xml_results

# Set the defaults for FreeNAS testing
set_defaults

# Set the default FreeNAS testing IP address
set_ip

# Run the REST tests now
run_tests

# Determine which VM backend to stop
if [ -n "$USE_BHYVE" ] ; then
  stop_bhyve
else
  stop_vbox
fi
