#!/bin/sh
# Meta pkg building startup script
#############################################

# Where is the pcbsd-build program installed
PROGDIR="`realpath | sed 's|/scripts||g'`" ; export PROGDIR

# Source the config file
. ${PROGDIR}/pcbsd.cfg

cd ${PROGDIR}/scripts

# Source our functions
. ${PROGDIR}/scripts/functions.sh

# Check if we have required programs
sh ${PROGDIR}/scripts/checkprogs.sh
cStat=$?
if [ $cStat -ne 0 ] ; then exit $cStat; fi

merge_pcbsd_src_ports()
{
   local mcwd=`pwd`
   local gitdir="$1"
   local portsdir="$2"
   distCache="/synth/distfiles"

   git_up "$gitdir" "$gitdir"
   rc_halt "cd ${gitdir}" >/dev/null 2>/dev/null
     
   # Now use the git script to create source ports
   rc_halt "./mkports.sh ${portsdir} ${distCache}"

   # Jump back to where we belong
   rc_halt "cd $mcwd" >/dev/null 2>/dev/null
}

mk_metapkg_bulkfile()
{
   local bulkList=$1
   rm $bulkList >/dev/null 2>/dev/null

   rc_halt "cp ${PCONFDIR}/essential-packages-nonrel $bulkList"
}

mk_synth_config()
{

if [ ! -d "/synth" ] ; then
  mkdir /synth
fi
if [ ! -d "/synth/ports-db" ] ; then
  mkdir /synth/ports-db
fi
if [ ! -d "/synth/distfiles" ] ; then
  mkdir /synth/distfiles
fi
if [ ! -d "/synth/log" ] ; then
  mkdir /synth/log
fi

# Get the memory in MB on system
MEM=$(sysctl -n hw.physmem)
MEM=$(expr $MEM / 1024)
MEM=$(expr $MEM / 1024)

CPUS=$(sysctl -n kern.smp.cpus)
if [ $CPUS -gt 2 ] ; then
  JOBS="2"
else
  JOBS="1"
fi

# Determine TMPFS usage based upon Memory to CPUs ratio
MEMPERBUILDER=$(expr $MEM / $CPUS)
if [ $MEMPERBUILDER -gt 4000 ]; then
  TMPWRK="true"
  TMPLB="true"
elif [ $MEMPERBUILDER -gt 2000 ] ; then
  TMPWRK="false"
  TMPLB="true"
else
  TMPWRK="false"
  TMPLB="false"
fi

cat >/usr/local/etc/synth/synth.ini << EOF
[Global Configuration]
profile_selected= PCBSD

[PCBSD]
Operating_system= FreeBSD
Directory_packages= $PPKGDIR
Directory_repository= $PPKGDIR
Directory_portsdir= /synth/ports
Directory_options= /synth/ports-db
Directory_distfiles= /synth/distfiles
Directory_buildbase= /usr/obj/synth-live
Directory_logs= /synth/log
Directory_ccache= disabled
Directory_system= /synth/world
Number_of_builders= $CPUS
Max_jobs_per_builder= $JOBS
Tmpfs_workdir= $TMPWRK
Tmpfs_localbase= $TMPLB
Display_with_ncurses= false
leverage_prebuilt= false
EOF

}

do_portsnap()
{
  echo "Removing old ports dir..."
  rm -rf /synth/ports 2>/dev/null >/dev/null
  mkdir /synth/ports

  echo "Cloning ports repo..."
  if [ -n "${PORTS_GIT_URL}" ] ; then
    git clone ${PORTS_GIT_URL} /synth/ports
  else
    git clone --depth=1 https://github.com/pcbsd/freebsd-ports.git /synth/ports
  fi

  # Need to checkout src as well
  echo "Preparing /usr/src..."
  rm -rf /usr/src 2>/dev/null
  mkdir /usr/src 2>/dev/null
  if [ -n "$GITFBSDURL" ] ; then
    git clone --depth=1 -b ${GITFBSDBRANCH} ${GITFBSDURL} /usr/src
  else
    git clone --depth=1 https://github.com/pcbsd/freebsd.git /usr/src
  fi

}

do_pcbsd_portmerge()
{
   # Copy our PCBSD port files
   merge_pcbsd_src_ports "${GITBRANCH}" "/synth/ports"
}

do_pbi-index()
{
   if [ -z "$PBI_REPO_KEY" ] ; then return ; fi

   # See if we can create the PBI index files for this repo
   if [ ! -d "$GITBRANCH/pbi-modules" ] ; then
      echo "No pbi-modules in this GIT branch"
      return 1
   fi

   echo "Building new PBI-INDEX"

   # Lets update the PBI-INDEX
   PKGREPO='local' ; export PKGREPO
   create_pkg_conf
   REPOS_DIR="${PROGDIR}/tmp/repo" ; export REPOS_DIR
   PKG_DBDIR="${PROGDIR}/tmp/repodb" ; export PKG_DBDIR
   if [ -d "$PKG_DBDIR" ] ; then rm -rf ${PKG_DBDIR}; fi
   mkdir -p ${PKG_DBDIR}
   ABIVER=`echo $TARGETREL | cut -d '-' -f 1 | cut -d '.' -f 1`
   PBI_PKGCFLAG="-o ABI=freebsd:${ABIVER}:x86:64" ; export PBI_PKGCFLAG

   rc_halt "cd ${GITBRANCH}/pbi-modules" >/dev/null 2>/dev/null
   rc_halt "pbi_makeindex ${PBI_REPO_KEY}"
   rc_nohalt "rm PBI-INDEX" >/dev/null 2>/dev/null
   rc_halt "mv PBI-INDEX.txz* ${PPKGDIR}/" >/dev/null 2>/dev/null
   return 0
}

if [ -z "$1" ] ; then
   target="all"
else
   target="$1"
fi

cd ${PROGDIR}

if [ ! -d "${GITBRANCH}" ]; then
   rc_halt "git clone ${GITPCBSDURL} ${GITBRANCH}"
fi
git_up "${GITBRANCH}" "${GITBRANCH}"
rc_halt "cd ${PCONFDIR}/" >/dev/null 2>/dev/null
cp ${PCONFDIR}/port-make.conf /usr/local/etc/synth/PCBSD-make.conf

if [ "$target" = "all" ] ; then

  # Remove old PBI-INDEX.txz files
  rm ${PPKGDIR}/PBI-INDEX.txz* 2>/dev/null

  # Create the synth config
  mk_synth_config

  # Extract the world for this synth build
  update_synth_world

  # Make sure this builder isn't already going
  pgrep -q synth
  if [ $? -eq 0 ] ; then
    # Kill old synth processes and wait / cleanup
    echo "Stopping old synth"
    killall -9 synth
    sleep 60
    synth status >/dev/null 2>/dev/null
  fi

  # Clean distfiles
  synth purge-distfiles

  # Build entire ports tree
  synth everything
  if [ $? -ne 0 ] ; then
     echo "Failed synth build..."
  fi

  # Sign the packages
  pkg repo ${PPKGDIR} signing_command: /etc/ssl/sign-pkgs.sh
  if [ $? -ne 0 ] ; then
     echo "Failed signing pkg repo!"
     exit 1
  fi

  # Make sure the essentials built, exit now if not
  check_essential_pkgs "NO"
  if [ $? -ne 0 ] ; then
     exit 1
  fi


  # Update the PBI index file
  do_pbi-index

  # Unset cleanup var
  pCleanup=""
  export pCleanup

  exit 0
elif [ "$1" = "portsnap" ] ; then
   do_portsnap
   do_pcbsd_portmerge
   exit 0
elif [ "$1" = "portmerge" ] ; then
   do_pcbsd_portmerge
   exit 0
elif [ "$1" = "pbi-index" ] ; then
   do_pbi-index
   exit $?
else
   echo "Invalid option!"
   exit 1
fi
