#!/usr/bin/env bash
# Log files
export RESTYOUT=/tmp/resty.out
export RESTYERR=/tmp/resty.err

#   $1 = Test Description
clean_xml_results() {
  if [ -d "$RESULTSDIR" ] ; then
    rm -rf "$RESULTSDIR"
  fi
  if [ -d "${WORKSPACE}/results" ] ; then
      rm -rf "${WORKSPACE}/results"
  fi
}

start_xml_results() {
  # Set total number of tests
  export TOTALCOUNT="0"

    if [ -n "${1}" ] ; then
      tnick="${1}"
    else
      tnick="FreeNAS QA Tests"
  fi
  if [ ! -d "$RESULTSDIR" ] ; then
    mkdir -p "$RESULTSDIR"
  fi
    export XMLRESULTS="$RESULTSDIR/results.xml.$$"
    cat >${XMLRESULTS} << EOF
<?xml version="1.0" encoding="UTF-8"?>
  <testsuite tests="TOTALTESTS" name="${tnick}">
EOF
}

#          $1 = true/false
#          $2 = error message
#  $CLASSNAME = Sub class of test results
#   $TESTNAME = Specific test name
# $TESTSTDOUT = stdout file of test results
# $TESTSTDERR = stderr file of test results
add_xml_result() {

  # If called when no tests have been setup, we can safely return
  if [ -z "$TESTNAME" ] ; then return 0 ; fi

  if [ -n "$TIMESTART" -a "$TIMESTART" != "0" ] ; then
    TIMEEND=`date +%s`
    TIMEELAPSED=`expr $TIMEEND - $TIMESTART`
  fi

  if [ "$1" = "true" ] ; then
    cat >>${XMLRESULTS} << EOF
    <testcase classname="$CLASSNAME" name="$TESTNAME" time="$TIMEELAPSED">
EOF
  elif [ "$1" = "skipped" ] ; then
    cat >>${XMLRESULTS} << EOF
    <testcase classname="$CLASSNAME" name="$TESTNAME"><skipped/>
EOF
  else
    # Failed!
    cat >>${XMLRESULTS} << EOF
    <testcase classname="$CLASSNAME" name="$TESTNAME" time="$TIMEELAPSED">
        <failure type="failure">$2</failure>
EOF
  fi

  local ESCAPED_TESTCMD=$(echo $TESTCMD | sed "s|&|&amp;|g")

  # Optional stdout / stderr logs
  if [ -n "$TESTSTDOUT" -a -e "$TESTSTDOUT" ] ; then
    echo -e "         <system-out>Command Run:\n$ESCAPE_TESTCMD\n\nResponse:\n" >> ${XMLRESULTS}
    echo "`cat $TESTSTDOUT | sed 's|<||g' | sed 's|>||g' | tr -d '\r'`</system-out>" >> ${XMLRESULTS}
  fi
  if [ -n "$TESTSTDERR" -a -e "$TESTSTDERR" ] ; then
    echo "         <system-err>`cat $TESTSTDERR | sed 's|<||g' | sed 's|>||g' | tr -d '\r'`</system-err>" >> ${XMLRESULTS}
  fi

  # Close the error tag
  cat >> ${XMLRESULTS} << EOF
    </testcase>
EOF

  unset TESTNAME TESTSTDOUT TESTSTDERR TESTCMD
}

# $1 = Optional tag for results file
finish_xml_results() {
  if [ -z "$1" ] ; then
    rTag="tests"
  else
    rTag="$1"
  fi

  cat >>${XMLRESULTS} << EOF
</testsuite>
EOF

  # Set the total number of tests run
  sed -i '' "s|TOTALTESTS|$1|g" ${XMLRESULTS}

  # Move results to pre-defined location
  if [ -n "$WORKSPACE" ] ; then
    if [ ! -d "${WORKSPACE}/results" ] ; then
      mkdir "${WORKSPACE}/results"
      chown jenkins:jenkins "${WORKSPACE}/results"
    fi
    tStamp=$(date +%s)
    echo "Saving jUnit results ${RESULTSDIR} -> ${WORKSPACE}/results/"
    mv $RESULTSDIR/results.xml.* "${WORKSPACE}/results/"
    chown -R jenkins:jenkins "${WORKSPACE}/results/"
  else
    echo "Saving jUnit results to: /tmp/test-results.xml"
    mv ${XMLRESULTS} /tmp/test-results.xml
  fi
}

publish_pytest_results() {
  # Set the total number of tests run
  sed -i '' "s|TOTALTESTS|$1|g" ${XMLRESULTS}

  # Move results to pre-defined location
  if [ -n "$WORKSPACE" ] ; then
    if [ ! -d "${WORKSPACE}/results" ] ; then
      mkdir "${WORKSPACE}/results"
      chown jenkins:jenkins "${WORKSPACE}/results"
    fi
    tStamp=$(date +%s)
    echo "Saving jUnit results ${RESULTSDIR} -> ${WORKSPACE}/results/"
    mv $RESULTSDIR/results.xml.* "${WORKSPACE}/results/"
    chown -R jenkins:jenkins "${WORKSPACE}/results/"
  else
    echo "Saving jUnit results to: /tmp/test-results.xml"
    mv ${XMLRESULTS} /tmp/test-results.xml
  fi
}


# $1 = RESTY type to run 
# $2 = RESTY URL
# $3 = JSON to pass to RESTY
rest_request()
{
  export TESTCMD="$2 $3"

  case $1 in
  DELETE) DELETE ${2} "${3}" -v >${RESTYOUT} 2>${RESTYERR} ; return $? ;;
     GET) GET ${2} "$3" -v >${RESTYOUT} 2>${RESTYERR} ; return $? ;;
   PATCH) PATCH ${2} "$3" -v >${RESTYOUT} 2>${RESTYERR} ; return $? ;;
     PUT) PUT ${2} "$3" -v >${RESTYOUT} 2>${RESTYERR} ; return $? ;;
    POST) POST ${2} "$3" -v >${RESTYOUT} 2>${RESTYERR} ; return $? ;;
   TRACE) POST ${2} "$3" -v >${RESTYOUT} 2>${RESTYERR} ; return $? ;;
       *) echo "Unknown RESTY command: $1" ; return 1 ;;
  esac

  # Shouldn't get here
  return 1;
}

# $1 = Command to run
# $2 = Command to run if $1 fails
# $3 = Optional timeout
rc_test()
{
  export TESTCMD="$1"
  export TESTSTDOUT="/tmp/.cmdTestStdOut"
  export TESTSTDERR="/tmp/.cmdTestStdErr"
  touch $TESTSTDOUT
  touch $TESTSTDERR

  if [ -z "$3" ] ; then
    eval "${1}" >${TESTSTDOUT} 2>${TESTSTDERR}
    if [ $? -ne 0 ] ; then
      echo_fail 
      if [ -n "$2" ] ; then 
        eval "${2}"
      fi
      echo "Failed running: $1"
      return 1
    else
      echo_ok
      return 0
    fi
  fi


  # Running with timeout
  ( ${1} >${TESTSTDOUT} 2>${TESTSTDERR} ; echo $? > /tmp/.rc-result.$$ ) &
  echo "$!" > /tmp/.rc-pid.$$
  timeout=0
  while :
  do
    # See if the process stopped yet
    pgrep -F /tmp/.rc-pid.$$ >/dev/null 2>/dev/null
    if [ $? -ne 0 ] ; then
      # Check if it was 0
      if [ "$(cat /tmp/.rc-result.$$)" = "0" ] ; then
        echo_ok
        rm /tmp/.rc-result.$$
        return 0
      fi
      rm /tmp/.rc-result.$$
      break
    fi

    # Check the timeout
    sleep 1
    timeout=$(expr $timeout + 1)
    if [ $timeout -gt $3 ] ; then break; fi
  done

  kill -9 $(cat /tmp/.rc-pid.$$)
  rm /tmp/.rc-pid.$$
  rm /tmp/.rc-result.$$ 2>/dev/null
  echo_fail
  eval "${2}"
  echo "Timeout running: $1"
  return 1
}

# $1 = Command to run
ssh_test()
{
  export TESTSTDOUT="/tmp/.sshCmdTestStdOut"
  export TESTSTDERR="/tmp/.sshCmdTestStdErr"
  touch $TESTSTDOUT
  touch $TESTSTDERR

  sshserver=${ip}
  if [ -z "$sshserver" ] ; then
    sshserver=$FNASTESTIP
  fi

  if [ -z "$sshserver" ] ; then
    echo "SSH server IP address required for ssh_test()."
    return 1
  fi

  # Test fuser value
  if [ -z "${fuser}" ] ; then
    echo "SSH server username required for ssh_test()."
    return 1
  fi

  # Use password auth if password set and no local ssh key found
  if [ -n "${fpass}" ] && ssh-add -l | grep -q 'The agent has no identities.'; then
    sshpass -p ${fpass} \
      ssh -o StrictHostKeyChecking=no \
          -o UserKnownHostsFile=/dev/null \
          -o VerifyHostKeyDNS=no \
          ${fuser}@${sshserver} ${1} >$TESTSTDOUT 2>$TESTSTDERR
  else
    ssh -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o VerifyHostKeyDNS=no \
        ${fuser}@${sshserver} ${1} >$TESTSTDOUT 2>$TESTSTDERR
  fi

  return $?
}

# $1 = Local file to copy to the remote host
# $2 = Location to store file on remote host
scp_to_test()
{
  _scp_test "${1}" "${fuser}@${sshserver}:${2}"
}

# $1 = File to copy from the remote host
# $2 = Location to copy file to
scp_from_test()
{
  _scp_test "${fuser}@${sshserver}:${1}" "${2}"
}

# Private method, see scp_from_test or scp_to_test
# $1 = SCP from [[user@]host1:]file1
# $2 = SCP to [[user@]host1:]file1
_scp_test()
{
  export TESTSTDOUT="/tmp/.scpCmdTestStdOut"
  export TESTSTDERR="/tmp/.scpCmdTestStdErr"
  touch $TESTSTDOUT
  touch $TESTSTDERR

  sshserver=${ip}

  if [ -z "$sshserver" ]; then
    sshserver=$FNASTESTIP
  fi

  if [ -z "$sshserver" ]; then
    echo "SCP server IP address request for scp_test()."
    return 1
  fi

  # Test fuser value
  if [ -z "${fuser}" ] ; then
    echo "SCP server username required for scp_test()."
    return 1
  fi

  # Use password auth if password set and no local ssh key found
  if [ -n "${fpass}" ] && ssh-add -l | grep -q 'The agent has no identities.'; then
    sshpass -p ${fpass} \
      scp -o StrictHostKeyChecking=no \
          -o UserKnownHostsFile=/dev/null \
          -o VerifyHostKeyDNS=no \
          "${1}" "${2}" >$TESTSTDOUT 2>$TESTSTDERR
  else
    scp -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o VerifyHostKeyDNS=no \
        "${1}" "${2}" >$TESTSTDOUT 2>$TESTSTDERR
  fi
  SCP_CMD_RESULTS=$?

  if [ $SCP_CMD_RESULTS -ne 0 ]; then
    echo "Failed on test module: $1"
    FAILEDMODULES="${FAILEDMODULES}:::${1}:::"
    return 1
  fi

  return $SCP_CMD_RESULTS
}

# $1 = Command to run
osx_test()
{
  export TESTSTDOUT="/tmp/.osxCmdTestStdOut"
  export TESTSTDERR="/tmp/.osxCmdTestStdErr"
  touch $TESTSTDOUT
  touch $TESTSTDERR

  if [ -z "${OSX_HOST}" ] ; then
    echo "SSH server IP address required for osx_test()."
    return 1
  fi

  if [ -z "${OSX_USERNAME}" ] ; then
    echo "SSH server username required for osx_test()."
    return 1
  fi

  # Use SSH keys if the $OSX_PASSWORD is not set
  if [ -n "${OSX_PASSWORD}" ]; then
    sshpass -p ${OSX_PASSWORD} \
      ssh -o StrictHostKeyChecking=no \
          -o UserKnownHostsFile=/dev/null \
          -o VerifyHostKeyDNS=no \
          ${OSX_USERNAME}@${OSX_HOST} ${1} >$TESTSTDOUT 2>$TESTSTDERR
  else
    ssh -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o VerifyHostKeyDNS=no \
        ${OSX_USERNAME}@${OSX_HOST} ${1} >$TESTSTDOUT 2>$TESTSTDERR
  fi

  return $?
}

# $1 = Command to run
bsd_test()
{
  export TESTSTDOUT="/tmp/.bsdCmdTestStdOut"
  export TESTSTDERR="/tmp/.bsdCmdTestStdErr"
  touch $TESTSTDOUT
  touch $TESTSTDERR

  if [ -z "${BSD_HOST}" ] ; then
    echo "SSH server IP address required for bsd_test()."
    return 1
  fi

  if [ -z "${BSD_USERNAME}" ] ; then
    echo "SSH server username required for bsd_test()."
    return 1
  fi

  # Use SSH keys if the $BSD_PASSWORD is not set
  if [ -n "${BSD_PASSWORD}" ]; then
    sshpass -p ${BSD_PASSWORD} \
      ssh -o StrictHostKeyChecking=no \
          -o UserKnownHostsFile=/dev/null \
          -o VerifyHostKeyDNS=no \
          ${BSD_USERNAME}@${BSD_HOST} ${1} >$TESTSTDOUT 2>$TESTSTDERR
  else
    ssh -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o VerifyHostKeyDNS=no \
        ${BSD_USERNAME}@${BSD_HOST} ${1} >$TESTSTDOUT 2>$TESTSTDERR
  fi

  return $?
}

echo_ok()
{
  echo -e " - OK"
  add_xml_result "true" "Valid test response"
}

echo_fail()
{
  if [ -z "$1" ] ; then
    errStr="Invalid test repsonse!"
  else
    errStr="$1"
  fi

  echo -e " - FAILED"
  add_xml_result "false" "$errStr"
}

echo_skipped()
{
  echo -e " - SKIPPED"
  add_xml_result "skipped" "Skipped test!"
}

# Checks the exit status_code from previous command
# (Optional) -q switch as first argument silences std_out
check_exit_status()
{
  STATUSCODE=$?
  SILENT="false"
  if [ "$1" == "-q" ]; then
    SILENT="true"
    shift
  fi

  if [ $STATUSCODE -eq 0 ]; then
    if [ "$SILENT" == "false" ]; then
      echo_ok
    fi
    return 0
  else
    if [ "$SILENT" == "false" ]; then
      echo_fail
    fi
    return 1
  fi  
}

# $1 = Expected status value for service state property (STOPPED|RUNNING|CRASHED)
# (Optional) -q switch as first argument silences std_out
check_service_status()
{
  SRV_PROPERTY='return this.srv_state'
  if [ "${1}" == "-q" ]; then
    check_property_value $1 "${SRV_PROPERTY}" $2
  else
    check_property_value "${SRV_PROPERTY}" $1
  fi
  return $?
}

# $1 = JSON property to check $2 (value) against, using JSAWK syntax
# $2 = Expected value returned by API property specified in $1
# (Optional) -q switch as first argument silences std_out
check_property_value()
{
  export TESTSTDOUT="$RESTYOUT"
  export TESTSTDERR="$RESTYERR"

  SILENT="false"
  if [ "${1}" == "-q" ]; then
    SILENT="true"
    shift
  fi

  grep -q "200 OK" ${RESTYERR}
  if [ $? -ne 0 ] ; then
    if [ "$SILENT" == "false" ]; then
      cat ${RESTYERR}
      cat ${RESTYOUT}
      echo_fail
    fi
    return 1
  fi  

  PROP_VALUE=`cat ${RESTYOUT} | ${JSAWK} "${1}"`
  # If 'srv_state' property not found, return 'SKIPPED' status
  # This can be removed once the API is in sync with TrueNAS/FreeNAS stable - 03/17/17, CD
  if [ "${1}" == "return this.srv_state" -a -z "$PROP_VALUE" ]; then
    if [ "$SILENT" == "false" ]; then
      echo_skipped
    fi
    return 0
  fi
  echo $PROP_VALUE | grep -q "${2}"
  if [ $? -ne 0 ]; then
    if [ "$SILENT" == "false" ]; then
      echo_fail
      echo "Expected: \"${2}\", Observed: \"${PROP_VALUE}\""
    fi
    return 1
  fi  

  if [ "$SILENT" == "false" ]; then
    echo_ok
  fi
  return 0
}

# Check for $1 REST response, error out if not found
check_rest_response()
{ 
  export TESTSTDOUT="$RESTYOUT"
  export TESTSTDERR="$RESTYERR"

  grep HTTP/1.1 ${RESTYERR}| grep -qi "$1"
  if [ $? -ne 0 ] ; then
    cat ${RESTYERR}
    cat ${RESTYOUT}
    echo_fail
    return 1
  fi

  echo_ok
  return 0
}

check_rest_response_continue()
{
  grep -q "$1" ${RESTYERR}
  return $?
}

set_test_group_text()
{
  GROUPTEXT="$1"
  CLASSNAME="$1"
  TOTALTESTS="$2"
  TCOUNT=0
}

echo_test_title()
{
  TESTNAME="$1"
  TCOUNT=`expr $TCOUNT + 1`
  TOTALCOUNT=`expr $TOTALCOUNT + 1`
  TIMESTART=`date +%s`
  sync
  echo -e "Running $GROUPTEXT ($TCOUNT/$TOTALTESTS) - $1\c"
}

#
set_defaults()
{
  fuser="root"
  fpass="testing"
}

wait_for_avail()
{
  # Sum: wait for 720 secs
  local LOOP_SLEEP=3
  local LOOP_LIMIT=240
  local ENDPOINT="/system/version/"

  local count=0
  while :
  do
    GET "${ENDPOINT}" -v 2>${RESTYERR} >${RESTYOUT}
    check_rest_response_continue "200 OK"
    check_exit_status -q && break
    echo -n "."
    sleep $LOOP_SLEEP
    if [ $count -gt $LOOP_LIMIT ] ; then
       echo_fail
       exit 1
    fi
    (( count++ ))
  done
}

# Use netcat to determine if a service port is open on FreeNAS
# $1 = Port number to check against
# $2 = (optional) Override $LOOP_SLEEP which determines how long to wait before retrying command
# $3 = (optional) Override $LOOP_LIMIT which determines how many loops before exiting with failure
wait_for_avail_port()
{
  local LOOP_SLEEP=1
  local LOOP_LIMIT=10
  local PORT=$1

  if [ -z "${PORT}" ]; then
    echo -n " wait_for_avail_port(): \$1 argument should be a port number to verify"
    return 1
  fi

  if [ -n "${2}" ]; then
    local LOOP_SLEEP=$2
  fi

  if [ -n "${3}" ]; then
    local LOOP_LIMIT=$3
  fi

  local loop_cnt=0
  while :
  do
    nc -z -n -v ${FNASTESTIP} ${PORT} 2>&1 | awk '$5 == "succeeded!" || $5 == "open"' >/dev/null 2>/dev/null
    check_exit_status -q && break
    echo -n "."
    sleep $LOOP_SLEEP
    if [ $loop_cnt -gt $LOOP_LIMIT ]; then
      return 1
    fi
    (( loop_cnt++ ))
  done
  return 0
}

# Use mount -l[ist] to determine if mounted share shows up
# $1 = Mountpoint to be used by share
# $2 = Share filesystem type (eg, smbfs)
wait_for_bsd_mnt()
{
  local LOOP_SLEEP=5
  local LOOP_LIMIT=60

  local loop_cnt=0

  while :
  do
    bsd_test "mount -l | grep -q \"${1}\""
    check_exit_status -q && break
    (( loop_cnt++ ))
    if [ $loop_cnt -gt $LOOP_LIMIT ]; then
      return 1
    fi
    sleep $LOOP_SLEEP
  done

  return 0
}

# Use mount to determine if mounted share shows up on OSX
# $1 = Mountpoint to be used by share
wait_for_osx_mnt()
{
  local LOOP_SLEEP=5
  local LOOP_LIMIT=60

  local pattern="${1}"
  local loop_cnt=0

  while :
  do
    osx_test "mount | grep -q \"${pattern}\""
    check_exit_status -q && break
    (( loop_cnt++ ))
    if [ $loop_cnt -gt $LOOP_LIMIT ]; then
      return 1
    fi
    sleep $LOOP_SLEEP
  done

  return 0
}


# SSH into OSX box and poll FreeNAS for running AFP service
wait_for_afp_from_osx()
{
  local LOOP_SLEEP=1
  local LOOP_LIMIT=10
  local AFP_PORT="548"

  local loop_cnt=0
  while :
  do
    osx_test "/System/Library/CoreServices/Applications/Network\ Utility.app/Contents/Resources/stroke ${BRIDGEIP} ${AFP_PORT} ${AFP_PORT} | grep ${AFP_PORT}"
    check_exit_status -q && break
    echo -n "."
    sleep $LOOP_SLEEP
    if [ $loop_cnt -gt $LOOP_LIMIT ]; then
      return 1
    fi
    (( loop_cnt++ ))
  done
  return 0
}

# Poll the FreeNAS host to verify when a share has been created by checking showmount -e results
# $1 = Mount path to check showmount results for
# $2 = (Optional) Access type of share (eg, "Everyone")
wait_for_fnas_mnt()
{
  local LOOP_SLEEP=2
  local LOOP_LIMIT=40

  local mntpoint=$1
  local permissions=""

  if [ -n "${2}" ]; then
    permissions=" && \$2 == \"${2}\""
  fi

  while :
  do
    ssh_test "showmount -e | awk '\$1 == \"${mntpoint}\"${permissions}' "
    check_exit_status -q && break
    echo -n "."
    sleep $LOOP_SLEEP
    if [ $loop_cnt -gt $LOOP_LIMIT ]; then
      return 1
    fi
    (( loop_cnt++ ))
  done
  return 0
}

run_module() {
  unset REQUIRES

  # Source the module now
  cd ${TDIR}
  . ./${1}
  if [ $? -ne 0 ] ; then
    echo "Failed sourcing ${1}"
    FAILEDMODULES="${FAILEDMODULES}:::${1}:::"
    return 1
  fi

  # Make sure any required module have been run first
  local modreq="$REQUIRES"
  local nofails="true"
  if [ -n "$modreq" ] ; then
    for i in $modreq
    do
      # Check if this module has already been run
      echo $RUNMODULES | grep -q ":::${i}:::"
      if [ $? -eq 0 ] ; then continue; fi

      echo $FAILEDMODULES | grep -q ":::${i}:::"
      if [ $? -eq 0 ] ; then
        CLASSNAME="$1"
        TESTNAME="all"
        TIMESTART="0"
        TOTALCOUNT=`expr $TOTALCOUNT + 1`
        echo "***** Skipping test module: $1 ($i failed) *****"
        add_xml_result "skipped" "Skipped due to $i requirement failing"
        FAILEDMODULES="${FAILEDMODULES}:::${1}:::"
        return 1
      fi

      # Need to run another module first
      echo "***** Running module dependancy: $i *****"
      run_module "$i" "quiet"
      if [ $? -ne 0 ] ; then
        nofails="false"
      fi
    done
  fi

  if [ "$nofails" = "false" ] ; then
    CLASSNAME="$1"
    TESTNAME="all"
    TIMESTART="0"
    TOTALCOUNT=`expr $TOTALCOUNT + 1`
    echo "***** Skipping test module: $1 (Dep failed) *****"
    add_xml_result "skipped" "Skipped test module: $i requirement failing"
    return 1
  fi

  # Run the target module
  if [ -z "$2" ] ; then
    echo "***** Running module: $1 *****"
  fi
  eval "${1}_init"
  if [ $? -ne 0 ] ; then
    echo "Failed on test module: $1"
    FAILEDMODULES="${FAILEDMODULES}:::${1}:::"
    return 1
  fi

  # Save that this test was already run
  RUNMODULES="${RUNMODULES}:::${1}:::"
  return 0
}

# Read through the test modules and start running them
read_module_dir() {
  cd ${TDIR}
  if [ $? -ne 0 ] ; then
    echo "Missing test module dir"
    exit 1
  fi

  RUNMODULES=""
  ANYFAILS="false"

  for module in `ls`
  do
    # Skip the README, other files should be valid though
    if [ "$module" = "README" ] ; then continue ; fi
    if [ "$module" = "example" ] ; then continue ; fi

    # Check if this module has already been run
    echo $RUNMODULES | grep -q ":::${module}:::"
    if [ $? -eq 0 ] ; then continue ; fi

    # Check if this module has already been skipped
    echo $FAILEDMODULES | grep -q ":::${module}:::"
    if [ $? -eq 0 ] ; then continue ; fi

    run_module "$module"
    if [ $? -ne 0 ] ; then
      ANYFAILS="true"
    fi
  done

  if [ "$ANYFAILS" = "true" ] ; then return 1; fi
  return 0 
}

run_tests() {
/ixbuild/jenkins.sh freenas-run-tests ${BUILDTAG}
}

# Do a TrueNAS HA failover
# $1 = reboot/panic
trigger_ha_failover() {
  case $1 in
    reboot) do_ha_reboot ;;
     panic) do_ha_panic ;;
         *) do_ha_reboot ;;
  esac
}

do_ha_panic() {
  export SSHPASS="$LIVEPASS"
  echo_test_title "Simulating kernel panic"
  sshpass -e ssh -o StrictHostKeyChecking=no ${LIVEUSER}@${LIVEHOST} sysctl debug.kdb.panic=1 >/dev/null 2>/dev/null
  echo_ok
  sleep 10

  echo_test_title "Waiting for active node response"
  sleep 20
  wait_for_avail
  echo_ok
}

do_ha_reboot() {
  echo_test_title "Rebooting to promote passive node to active"
  rest_request "POST" "/system/reboot/" "''"
  echo_ok

  echo_test_title "Waiting for active node response"
  sleep 20
  wait_for_avail
  echo_ok
}

do_ha_status() {
  # Verify each node is now in a normal state
  count=0
  while :
  do
    # Check the status of each node to make sure all nodes are online
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
}
