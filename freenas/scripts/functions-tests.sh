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

# Optional stdout / stderr logs
  if [ -n "$TESTSTDOUT" -a -e "$TESTSTDOUT" ] ; then
    echo -e "         <system-out>Command Run:\n$TESTCMD\n\nResponse:\n" >> ${XMLRESULTS}
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
    ${1} >${TESTSTDOUT} 2>${TESTSTDERR}
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
# $2 = Command to run if $1 fails
# $3 = Optional timeout
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

  # Test fuser and fpass values
  if [ -z "${fpass}" ] || [ -z "${fuser}" ] ; then
    echo "SSH server username and password required for ssh_test()."
    return 1
  fi

  # Make SSH connection
  sshpass -p ${fpass} \
    ssh -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o VerifyHostKeyDNS=no \
        ${fuser}@${sshserver} ${1} >$TESTSTDOUT 2>$TESTSTDERR
  SSH_COMMAND_RESULTS=$?

  if [ ${SSH_COMMAND_RESULTS} -ne 0 ] ; then
    echo "Failed on test module: $1"
    FAILEDMODULES="${FAILEDMODULES}:::${1}:::"
    return 1
  fi

  return $SSH_COMMAND_RESULTS
}

# $1 = Command to run
# $2 = Command to run if $1 fails
# $3 = Optional timeout
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

  if [ -z "${OSX_USERNAME}" ] || [ -z "${OSX_PASSWORD}" ] ; then
    echo "SSH server username and password required for osx_test()."
    return 1
  fi

  # Make SSH connection
  sshpass -p ${OSX_PASSWORD} \
    ssh -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o VerifyHostKeyDNS=no \
        ${OSX_USERNAME}@${OSX_HOST} ${1} >$TESTSTDOUT 2>$TESTSTDERR
  SSH_COMMAND_RESULTS=$?

  if [ ${SSH_COMMAND_RESULTS} -ne 0 ] ; then
    echo "Failed on test module: $1"
    FAILEDMODULES="${FAILEDMODULES}:::${1}:::"
    return 1
  fi
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
check_exit_status()
{
  STATUSCODE=$?
  if [ $STATUSCODE -eq 0 ]; then
    echo_ok
    return 0
  else
    echo_fail
    return 1
  fi  
}

# $1 = JSON service property to check using JSAWK syntax
# $2 = Expected status indicator of service
check_service_status()
{
  export TESTSTDOUT="$RESTYOUT"
  export TESTSTDERR="$RESTYERR"

  grep -q "200 OK" ${RESTYERR}
  if [ $? -ne 0 ] ; then
    cat ${RESTYERR}
    cat ${RESTYOUT}
    echo_fail
    return 1
  fi  

  SRVSTATUS=`cat ${RESTYOUT} | ${JSAWK} "${1}"`
  echo $SRVSTATUS | grep -q $2
  if [ $? -ne 0 ]; then
    echo_fail
    echo "Expected: \"${2}\", Observed: \"${SRVSTATUS}\""
    return 1
  fi  

  echo_ok
  return 0
}

# Check for $1 REST response, error out if not found
check_rest_response()
{ 
  export TESTSTDOUT="$RESTYOUT"
  export TESTSTDERR="$RESTYERR"

  grep -q "$1" ${RESTYERR}
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
if [ -n "$FREENASLEGACY" ] ; then
  count=0
  while :
  do
    GET /storage/disk/ -v 2>${RESTYERR} >${RESTYOUT}
    check_rest_response_continue "200 OK"
    if [ $? -eq 0 ] ; then break; fi
    echo -e ".\c"
    sleep 60
    if [ $count -gt 12 ] ; then
       echo_fail
       exit 1
    fi
    count=`expr $count + 1`
  done
else
  count=0
  while :
  do
    GET /system/info/hardware/ -v 2>${RESTYERR} >${RESTYOUT}
    check_rest_response_continue "200 OK"
    if [ $? -eq 0 ] ; then break; fi
    echo -e ".\c"
    sleep 60
    if [ $count -gt 12 ] ; then
       echo_fail
       exit 1
    fi
    count=`expr $count + 1`
  done
fi
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
