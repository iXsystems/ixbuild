#!/usr/local/bin/bash

# Where is the pcbsd-build program installed
PROGDIR="`realpath | sed 's|/scripts$||g'`" ; export PROGDIR

# Make sure we have all the required packages installed
${PROGDIR}/scripts/checkprogs.sh

# Source our functions
. ${PROGDIR}/scripts/functions.sh
. ${PROGDIR}/scripts/functions-tests.sh

if [ ! -d "${PROGDIR}/tmp" ] ; then
  mkdir ${PROGDIR}/tmp
fi

# Figure out the flavor for this test
echo $BUILDTAG | grep -q "truenas"
if [ $? -eq 0 ] ; then
  FLAVOR="TRUENAS"
else
  FLAVOR="FREENAS"
fi

# Source our resty / jsawk functions
. ${PROGDIR}/../utils/resty -W "http://${LIVEHOST}:80/api/v1.0" -H "Accept: application/json" -H "Content-Type: application/json" -u ${LIVEUSER}:${LIVEPASS}

# Start the XML reporting
start_xml_results "Live Testing"

# Check that the server is up and ready to answer calls
set_test_group_text "Testing Connectivity" "1"
echo_test_title "Testing access to REST API"
wait_for_avail
echo_ok

if [ "$FLAVOR" = "FREENAS" ] ; then
  set_test_group_text "Upgrade Test" "2"

  # Checking for updates
  echo_test_title "Checking for available updates"
  rest_request "GET" "/system/update/check/" "''"
  check_rest_response "200 OK"

  # Do the update now
  echo_test_title "Performing upgrade of system"
  rest_request "POST" "/system/update/update/" "''"
  check_rest_response "200 OK"

  # Wait for system to reboot
  echo_test_title "Waiting for reboot"
  sleep 20
  wait_for_avail
  echo_ok
else
  # For TrueNAS we have to do the update in two stages, one for each head
  foo=1

fi

finish_xml_results
