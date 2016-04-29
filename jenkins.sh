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

display_usage() {

	 cat << EOF
Available Commands:

-- FreeNAS Commands --
      freenas - Builds FreeNAS release
freenas-tests - Runs FreeNAS VM API tests against built release
freenas-combo - Build release and run VM API tests against it automatically
freenas-ltest - Runs the FreeNAS "live" tests against a target system
freenas-lupgrade - Runs the FreeNAS "live" upgrade against a target system


-- PC-BSD Commands --
  world - Build FreeBSD world
   jail - Prep the jail for package build
    pkg - Build packages
    iso - Assemble PC-BSD ISO files
     vm - Assemble PC-BSD VM images
EOF

}

if [ -z "$1" ] ; then
  display_usage
  exit 1
fi
 
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
freenas-ltest) jenkins_freenas_live_tests ;;
freenas-lupgrade) jenkins_freenas_live_upgrade ;;
freenas-combo) jenkins_freenas
	       jenkins_freenas_tests ;;
ports-tests) jenkins_ports_tests ;;
      *) echo "Invalid command: $1" 
         display_usage
         exit 1
         ;;
esac
