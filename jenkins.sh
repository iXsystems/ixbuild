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
    iso) jekins_iso ;;
     vm) jekins_vm ;;
freenas) jekins_freenas ;;
      *) echo "Invalid Type: $1" 
         exit 1
         ;;
esac
