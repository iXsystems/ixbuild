#!/usr/bin/env bash
CURRDIR="$(realpath "$(dirname "$0")")"

source "${CURRDIR}/../../build.conf"
if [ -f "${CURRDIR}/config.local" ]; then
  source "${CURRDIR}/config.local"
else
  source "${CURRDIR}/config.prod"
fi

TESTSUITES=( "dojo" "angular" )

# Allow argument for running a single version of the testsuite
if [ -n "$1" ]; then
  if [ -d "${CURRDIR}/$1" ]; then
    TESTSUITES=( "$1" )
  else
    echo "No test suite found for \"$1\". Available test suites: ${TESTSUITES[@]}"
    exit 1
  fi
fi

for testsuite in ${TESTSUITES[@]}
do
  "${CURRDIR}/${testsuite}/runtests.sh"
done
