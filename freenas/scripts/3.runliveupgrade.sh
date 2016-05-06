#!/usr/local/bin/bash

# Where is the pcbsd-build program installed
PROGDIR="`realpath | sed 's|/scripts$||g'`" ; export PROGDIR

# Make sure we have all the required packages installed
${PROGDIR}/scripts/checkprogs.sh

# Source our functions
. ${PROGDIR}/scripts/functions.sh
. ${PROGDIR}/scripts/functions-tests.sh

# Set variable to call jsawk utility
JSAWK="${PROGDIR}/../utils/jsawk -j js24"

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
  set_test_group_text "FreeNAS Upgrade Test" "4"

  # Checking for updates
  echo_test_title "Checking for available updates"
  rest_request "GET" "/system/update/check/" ""
  check_rest_response "200 OK"

  # Do the update now
  echo_test_title "Performing upgrade of system"
  rest_request "POST" "/system/update/update/" "{}"
  check_rest_response "200 OK"

  echo_test_title "Rebooting VM"
  rest_request "POST" "/system/reboot/" "''"
  echo_ok

  # Wait for system to reboot
  echo_test_title "Waiting for reboot"
  sleep 20
  wait_for_avail
  echo_ok
else
  # For TrueNAS we have to do the update in two stages, one for each head
  set_test_group_text "TrueNAS Upgrade Test" "8"

  # Checking for updates on nodeA
  echo_test_title "Checking for available updates"
  rest_request "GET" "/system/update/check/" ""
  check_rest_response "200 OK"

  # Do the update now
  echo_test_title "Performing upgrade of system"
  rest_request "POST" "/system/update/update/" "{}"
  check_rest_response "200 OK"

  echo_test_title "Rebooting VM"
  rest_request "POST" "/system/reboot/" "''"
  echo_ok

  # Wait for system to reboot
  echo_test_title "Waiting for reboot"
  sleep 20
  wait_for_avail
  echo_ok

  # Wait for HA to come back up
  count=0
  while : 
  do
    # Check the status of each node to make sure all nodes are online
    echo_test_title "Checking to make sure each node is online to continue upgrade"
    rest_request "GET" "/system/alert/" ""
    check_rest_response "200 OK"
    NODESTATUS=$(cat ${RESTYOUT} | ${JSAWK} 'return this.message')
    echo "NODESTATUS: $NODESTATUS"
    echo $NODESTATUS | grep -q 'TrueNAS versions mismatch in failover. Update both nodes to the same version.'
    if [ $? -eq 0 ] ; then
      break  
    else
      sleep 30
    fi
    count=$(expr $count + 1)
    if [ $count -gt 20 ] ;
    then
      echo_fail
      finish_xml_results
      exit 1
    fi
  done

  # Checking for updates on nodeB
  echo_test_title "Checking for available updates"
  rest_request "GET" "/system/update/check/" ""
  check_rest_response "200 OK"

  # Do the update now
  echo_test_title "Performing upgrade of system"
  rest_request "POST" "/system/update/update/" "{}"
  check_rest_response "200 OK"

  echo_test_title "Rebooting VM"
  rest_request "POST" "/system/reboot/" "''"
  echo_ok

  # Wait for system to reboot
  echo_test_title "Waiting for reboot"
  sleep 20
  wait_for_avail
  echo_ok

  # Verify each node is now in a normal state
  count=0
  while :
  do
    # Check the status of each node to make sure all nodes upgraded
    echo_test_title "Checking the alert level for each node"
    rest_request "GET" "/system/alert/" ""
    check_rest_response "200 OK"
    NODESTATUS=$(cat ${RESTYOUT} | ${JSAWK} 'return this.message')
    echo "NODESTATUS: $NODESTATUS"
    echo $NODESTATUS | grep -q 'Failed to check failover status with the other node: timed out'
    if [ $? -ne 0 ] ; then
      break
    else
      sleep 30
    fi
    count=$(expr $count + 1)
    if [ $count -gt 20 ] ;
    then
      echo_fail
      finish_xml_results
      exit 1
    fi
  done

fi

finish_xml_results
