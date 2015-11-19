#!/bin/sh

# Set the variables
TYPE="${1}"
BUILD="${2}"
BRANCH="${3}"

# Change directory
mypath=`realpath $0`
cd `dirname $mypath`

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
      *) echo "Invalid Type: $1" 
         exit 1
         ;;
esac
