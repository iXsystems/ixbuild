#!/bin/sh

# Change directory
mypath=`realpath $0`
cd `dirname $mypath`
export PROGDIR="`realpath`"

if [ -z "$JENKINS_DO_UPDATE" ] ; then

  # Git pull may fail if this isn't set
  if [ -z "$(git config --global user.email)" ] ; then
    git config --global user.email "jenkins@example.com"
    git config --global user.name "Jenkins Node"
  fi

  # Before we begin any build, make sure we are updated from git
  git reset --hard
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

# Pkg does stuff now with ABIs and it prevents updating the database
export IGNORE_OSVERSION="YES"

display_usage() {

   cat << EOF
Available Commands:

-- FreeNAS Commands --
freenas                  - Builds FreeNAS release
freenas-docs             - Create FreeNAS Handbook
freenas-tn-docs          - Create TrueNAS Handbook
freenas-api              - Create FreeNAS API
freenas-push-docs        - Push FreeNAS Docs
freenas-push-tn-docs     - Push TrueNAS Docs
freenas-push-api         - Push FreeNAS API
freenas-push-nightly     - Run 'release-push' for FreeNAS Nightly
freenas-push             - Run 'release-push' for FreeNAS / TrueNAS
mkcustard                - Build a Custard VM
mktrueview               - Build a TrueView VM

-- TrueOS Commands --
trueos-world             - Builds the world
trueos-pkg               - Builds the entire pkg repo
trueos-iso-pkg           - Builds just the pkgs needed for ISO creation
trueos-iso               - Builds the ISO files
trueos-vm                - Builds the VM images
publish-iso              - Upload ISO files to ScaleEngine
publish-iso-edge         - Upload ISO files to ScaleEngine (Bleeding Edge)
publish-pkg              - Upload PKG files to ScaleEngine
publish-pkg-edge         - Upload PKG files to ScaleEngine (Bleeding Edge)
publish-pkg-unstable     - Upload PKG files to ScaleEngine (Unstable)
publish-pkg-ipfs         - Add and pin PKG files to IPFS repo
promote-pkg              - Promote packages from UNSTABLE -> STABLE
trueos-docs              - Create TrueOS handbook
push-trueos-docs         - Upload TrueOS handbook
lumina-docs              - Create lumina handbook
push-lumina-docs         - Upload lumina handbook
ports-tests              - Test building a repo port files

-- SysAdm Commands --
sysadm-docs              - Build SysAdm handbook
push-sysadm-docs         - Upload SysAdm handbook
sysadm-api               - Build SysAdm API handbook
push-sysadm-api          - Upload SysAdm API handbook

-- iocage Commands --
iocage_pkgs              - Build iocage package set
iocage_pkgs_push         - Push iocage package set public
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
            trueos-world) jenkins_world ;;
              trueos-pkg) jenkins_pkg "release" ;;
          trueos-iso-pkg) jenkins_pkg "iso" ;;
              sysadm-api) jenkins_sysadm_api ;;
         push-sysadm-api) jenkins_sysadm_push_api ;;
             sysadm-docs) jenkins_sysadm_docs ;;
        push-sysadm-docs) jenkins_sysadm_push_docs ;;
             trueos-docs) jenkins_trueos_docs ;;
        push-trueos-docs) jenkins_trueos_push_docs ;;
             lumina-docs) jenkins_trueos_lumina_docs ;;
        push-lumina-docs) jenkins_trueos_push_lumina_docs ;;
              trueos-iso) jenkins_iso ;;
             publish-iso) jenkins_publish_iso ;;
        publish-iso-edge) jenkins_publish_iso "edge" ;;
             publish-pkg) jenkins_publish_pkg ;;
        publish-pkg-edge) jenkins_publish_pkg "edge" ;;
    publish-pkg-unstable) jenkins_publish_pkg "unstable" ;;
        publish-pkg-ipfs) jenkins_publish_pkg_ipfs ;;
 publish-pkg-ipfs-stable) jenkins_publish_pkg_ipfs "stable" ;;
             promote-pkg) jenkins_promote_pkg ;;
               trueos-vm) jenkins_vm ;;
                    jail) jenkins_jail ;;
             iocage_pkgs) jenkins_iocage_pkgs ;;
        iocage_pkgs_push) jenkins_iocage_pkgs_push ;;
                 freenas) jenkins_freenas ;;
         freenas-tn-docs) jenkins_truenas_docs ;;
            freenas-docs) jenkins_freenas_docs ;;
       freenas-push-docs) jenkins_freenas_push_docs ;;
    freenas-push-tn-docs) jenkins_truenas_push_docs ;;
             freenas-api) jenkins_freenas_api ;;
        freenas-push-api) jenkins_freenas_push_api ;;
         freenas-push-be) jenkins_freenas_push_be ;;
    freenas-push-nightly) jenkins_freenas_push_nightly ;;
            freenas-push) jenkins_freenas_push ;;
           freenas-combo) jenkins_freenas
                          jenkins_freenas_tests
                          ;;
               mkcustard) jenkins_mkcustard ;;
              mktrueview) jenkins_mktrueview ;;
             ports-tests) jenkins_ports_tests ;;
                       *) echo "Invalid command: $1"
                          display_usage
                          exit 1
                          ;;
esac
