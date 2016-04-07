#   $1 = Test Description
start_xml_results() {
  if [ -n "${1}" ] ; then
    tnick="${1}"
  else
    tnick="FreeNAS QA Tests"
  fi

  export XMLRESULTS="/tmp/.results.xml.$$"
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

finish_xml_results() {
  cat >>${XMLRESULTS} << EOF
</testsuite>
EOF

  # Set the total number of tests run
  sed -i '' "s|TOTALTESTS|$1|g" ${XMLRESULTS}

  # Move results to pre-defined location
  if [ -n "$WORKSPACE" ] ; then
    if [ ! -d "${WORKSPACE}/results" ] ; then
      mkdir -p "${WORKSPACE}/results"
      chown jenkins:jenkins "${WORKSPACE}/results"
    fi
    tStamp=$(date +%s)
    echo "Saving jUnit results to: ${WORKSPACE}/results/freenas-${BUILD_TAG}-results-${tStamp}.xml"
    mv "${XMLRESULTS}" "${WORKSPACE}/results/freenas-${BUILD_TAG}-results-${tStamp}.xml"
    chown jenkins:jenkins "${WORKSPACE}/results/freenas-${BUILD_TAG}-results-${tStamp}.xml"
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

  # If building from Jenkins
  if [ -n "$WORKSPACE" ] ; then
    # Display the output
    (tail -f ${TESTSTDOUT}) &
    TPID="$!"
  fi

  if [ -z "$3" ] ; then
    ${1} >>${TESTSTDOUT} 2>>${TESTSTDERR}
    if [ $? -ne 0 ] ; then
       if [ -n "$TPID" ] ; then kill -9 $TPID; fi
       echo_fail 
       eval "${2}"
       echo "Failed running: $1"
       return 1
    fi
    if [ -n "$TPID" ] ; then kill -9 $TPID; fi
    echo_ok
    return 0
  fi


  # Running with timeout
  ( ${1} >>${TESTSTDOUT} 2>>${TESTSTDERR} ; echo $? > /tmp/.rc-result.$$ ) &
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

echo_ok()
{
  echo -e " - OK"
  add_xml_result "true" "Valid test response"
}

echo_fail()
{
  echo -e " - FAILED"
  add_xml_result "false" "Invalid test response!"
}

echo_skipped()
{
  echo -e " - SKIPPED"
  add_xml_result "skipped" "Skipped test!"
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

# Set the IP address of REST
set_ip()
{
  set_test_group_text "Networking Configuration" "4"

  echo_test_title "Setting IP address: ${ip} on em0"
  if [ "$manualip" = "NO" ] ; then
    rest_request "POST" "/network/interface/" '{ "int_ipv4address": "'"${ip}"'", "int_name": "internal", "int_v4netmaskbit": "24", "int_interface": "em0" }'
    check_rest_response "201 CREATED"
  else
    echo_ok
  fi

  echo_test_title "Setting DHCP on em1"
  rest_request "POST" "/network/interface/" '{ "int_dhcp": true, "int_name": "ext", "int_interface": "em1" }'
  check_rest_response "201 CREATED"

  echo_test_title "Rebooting VM"
  rest_request "POST" "/system/reboot/" "''"
  # Disabled the response check, seems the reboot happens fast enough to
  # prevent a valid response sometimes
  #check_rest_response "202 ACCEPTED"
  echo_ok

  echo_test_title "Waiting for reboot"
  sleep 20
  wait_for_avail
  echo_ok
}

wait_for_avail()
{
  count=0
  while :
  do
    GET /storage/disk/ -v 2>${RESTYERR} >${RESTYOUT}
    check_rest_response_continue "200 OK"
    if [ $? -eq 0 ] ; then break; fi
    echo -e ".\c"
    sleep 60
    if [ $count -gt 10 ] ; then
       echo_fail
       exit 1
    fi
    count=`expr $count + 1`
  done
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
