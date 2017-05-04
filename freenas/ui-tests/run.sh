#!/usr/bin/env bash
CURRDIR="$(realpath "$(dirname "$0")")"

CMD=$1
MODULE=$2

source "${CURRDIR}/../../build.conf"
if [ -f "${CURRDIR}/config.local" ]; then
  source "${CURRDIR}/config.local"
else
  source "${CURRDIR}/config.prod"
fi

runtests()
{
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

  return 0
}

case "${CMD,,}" in
  tests)  runtests ;;
angular)  runtests "angular" ;;
   dojo)  runtests "dojo" ;;
      *) echo "Usage: $0 [tests|dojo|angular]" && exit 1 ;;
esac
