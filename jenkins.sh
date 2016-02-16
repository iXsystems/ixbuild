#!/bin/sh

# Change directory
mypath=`realpath $0`
cd `dirname $mypath`

if [ -z "$JENKINS_DO_UPDATE" ] ; then
  # Before we begin any build, make sure we are updated from git
  git pull
  export JENKINS_DO_UPDATE="YES"
  ./jenkins.sh "$1" "$2" "$3"
  exit $?
fi

# Set the variables
TYPE="${1}"
BUILD="${2}"
BRANCH="${3}"

# Set JENKINS var
export USING_JENKINS="YES"

# Source our functions
. build.conf
. functions.sh
######################################################

case $TYPE in
  world) jenkins_world ;;
   jail) jenkins_jail ;;
    pkg) jenkins_pkg ;; 
    iso) jenkins_iso ;;
     vm) jenkins_vm ;;
freenas) jenkins_freenas ;;
freenas-tests) jenkins_freenas_tests ;;
freenas-combo) jenkins_freenas
	       jenkins_freenas_tests ;;
ports-tests) jenkins_ports_tests ;;
      *) echo "Invalid command: $1" 
	 cat << EOF
Available Commands:

-- FreeNAS Commands --
      freenas - Builds FreeNAS release
freenas-tests - Runs FreeNAS tests against built release
freenas-combo - Build release and run API tests against it automatically

-- PC-BSD Commands --
  world - Build FreeBSD world
   jail - Prep the jail for package build
    pkg - Build packages
    iso - Assemble PC-BSD ISO files
     vm - Assemble PC-BSD VM images
EOF
         exit 1
         ;;
esac
