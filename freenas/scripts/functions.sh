#!/bin/sh

# Most of these dont need to be modified
#########################################################

# Source vars
if [ -z "${PROGDIR}" ] ; then
  . ../freenas.cfg
else
  . ${PROGDIR}/freenas.cfg
fi

# Where on disk is the FreeNAS GIT branch
if [ -n "$FNASGITDIR" ] ; then
  FNASSRC="${FNASGITDIR}"
  export FNASSRC
else
  FNASSRC="${PROGDIR}/freenas"
  export FNASSRC
fi

# Set the local location of XML results
if [ -z "$RESULTSDIR" ] ; then
  RESULTSDIR="/tmp/${BUILDTAG}"
  export RESULTSDIR
fi

git_fnas_up()
{
  local lDir=${1}
  local rDir=${2}
  local oDir=`pwd`
  cd "${lDir}"

  git reset --hard

  echo "GIT pull"
  git pull
  if [ $? -ne 0 ] ; then
     exit_err "Failed doing a git pull"
  fi

  echo "Done with git_fnas_up()"
  cd "${oDir}"
  return 0
}

exit_err() {
   echo "ERROR: $@"
   exit 1
}

# Run-command, don't halt if command exits with non-0
rc_nohalt()
{
  local CMD="$1"

  if [ -z "${CMD}" ]
  then
    exit_err "Error: missing argument in rc_nohalt()"
  fi

  ${CMD} 2>/dev/null >/dev/null

};

# Run-command, halt if command exits with non-0
rc_halt()
{
  local CMD="$1"
  if [ -z "${CMD}" ]; then
    exit_err "Error: missing argument in rc_halt()"
  fi

  echo "Running command: $CMD"
  ${CMD}
  if [ $? -ne 0 ]; then
    exit_err "Error ${STATUS}: ${CMD}"
  fi
};
