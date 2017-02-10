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
  RESULTSDIR="/tmp/results/${BUILDTAG}"
  export RESULTSDIR
fi

# Default IP4 Pool of addresses
DEFAULT_IP4POOL="$(grep ^IP4POOL: /ixbuild/build.conf | cut -d' ' -f2)"
if [ -z "$DEFAULT_IP4POOL" ] ; then
   DEFAULT_IP4POOL="192.168.0.220"
   export DEFAULT_IP4POOL
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

clean_artifacts() 
{
  # Move artifacts to pre-defined location
    echo "Cleaning previous artifacts"
    rm -rf "${WORKSPACE}/artifacts/"
}

save_artifacts_on_fail()
{
  get_bedir

  # Move artifacts to pre-defined location
  if [ -n "$ARTIFACTONFAIL" ] ; then
      if [ -n "$WORKSPACE" ] ; then
        if [ ! -d "${WORKSPACE}/artifacts" ] ; then
            mkdir "${WORKSPACE}/artifacts"
            chown jenkins:jenkins "${WORKSPACE}/artifacts"
              if [ ! -d "${WORKSPACE}/artifacts/logs" ] ; then
                mkdir "${WORKSPACE}/artifacts/logs"
	        chown jenkins:jenkins "${WORKSPACE}/artifacts/logs"
                if [ ! -d "${WORKSPACE}/artifacts/ports" ] ; then
		  mkdir "${WORKSPACE}/artifacts/ports"
                  chown jenkins:jenkins "${WORKSPACE}/artifacts/ports"
          fi
        fi
      fi
    fi
    echo "Saving artifacts to: ${WORKSPACE}/artifacts"
    cp -R "${BEDIR}/objs/logs/" "${WORKSPACE}/artifacts/logs/"
    cp -R "${BEDIR}/objs/ports/logs/" "${WORKSPACE}/artifacts/ports/"
    chown -R jenkins:jenkins "${WORKSPACE}/artifacts/"
  else
    echo "Skip saving artificats on failure / ARTIFACTONFAIL not set"
  fi
}

save_artifacts_on_success() 
{
  # Move artifacts to pre-defined location
  if [ -n "$ARTIFACTONSUCCESS" ] ; then
    if [ -n "$WORKSPACE" ] ; then
        if [ ! -d "${WORKSPACE}/artifacts" ] ; then
            mkdir "${WORKSPACE}/artifacts"
            chown jenkins:jenkins "${WORKSPACE}/artifacts"
              if [ ! -d "${WORKSPACE}/artifacts/logs" ] ; then
                mkdir "${WORKSPACE}/artifacts/logs"
	        chown jenkins:jenkins "${WORKSPACE}/artifacts/logs"
                if [ ! -d "${WORKSPACE}/artifacts/ports" ] ; then
		  mkdir "${WORKSPACE}/artifacts/ports"
                  chown jenkins:jenkins "${WORKSPACE}/artifacts/ports"
          fi
        fi
      fi
    fi
    echo "Saving artifacts to: ${WORKSPACE}/artifacts"
    cp -R "${BEDIR}/objs/logs/" "${WORKSPACE}/artifacts/logs/"
    cp -R "${BEDIR}/objs/ports/logs/" "${WORKSPACE}/artifacts/ports/"
    chown -R jenkins:jenkins "${WORKSPACE}/artifacts/"
  else
    echo "Skip saving artificats on success / ARTIFACTONSUCCESS not set"
  fi
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

# Set the FreeNAS _BE directory location
get_bedir()
{

  if [ -d "${FNASBDIR}/${PROFILE}/_BE" ] ; then
    export BEDIR="${FNASBDIR}/${PROFILE}/_BE"
    return 0
  fi 

  if [ "${GITFNASBRANCH}" != "master" ] ; then
    export BEDIR="${FNASBDIR}/_BE"
    return 0
  fi

  if [ -n "$BUILDOPTS" ] ; then
    eval $BUILDOPTS
  fi

  if [ "$PROFILE" != "freenas10" ] ; then
    export BEDIR="${FNASBDIR}/${PROFILE}/_BE"
  else
    export BEDIR="${FNASBDIR}/_BE"
  fi
}
