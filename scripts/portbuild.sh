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
   if [ "$ARCH" == "i386" ] ; then return 0 ; fi

   local mcwd=`pwd`
   local gitdir="$1"
   local portsdir="$2"
   local distCache=`grep '^DISTFILES_CACHE=' /usr/local/etc/poudriere.conf | cut -d '=' -f 2`
   if [ -z "$distCache" ] ; then
      exit_err "Need a DISTFILES_CACHE in poudriere.conf"
   fi

   if [ ! -d "$distCache" ] ; then rc_halt "mkdir -p ${distCache}" ; fi
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

do_portsnap()
{
   cp /usr/local/etc/poudriere.conf /tmp/.poudriere.conf.$$
   cat /usr/local/etc/poudriere.conf | grep -v "GIT_URL" > /tmp/.poud.tmp.$$
   echo "GIT_URL=\"$PORTS_GIT_URL\" ; export GIT_URL" >> /tmp/.poud.tmp.$$
   mv /tmp/.poud.tmp.$$ /usr/local/etc/poudriere.conf

   echo "Updating ports collection..."
   poudriere ports -l | grep -q -w "^${POUDPORTS}" 
   if [ $? -eq 0 ] ; then

     # Stop the jail in case its running
     poudriere jail -k -j $PBUILD -p $POUDPORTS

     echo "Removing old ports tree ${POUDPORTS}"
     poudriere ports -d -p "$POUDPORTS"
     if [ $? -ne 0 ] ; then
       echo "Failed to delete ports $POUDPORTS"
       mv /tmp/.poudriere.conf.$$ /usr/local/etc/poudriere.conf
       exit 1
     fi

     if [ -d "$PJPORTSDIR" ] ; then
	echo "Removing old $PJPORTSDIR"
	rm -rf $PJPORTSDIR
     fi
   fi
   sleep 4
   poudriere ports -c -m git -p "$POUDPORTS" >/dev/null 2>/dev/null
   if [ $? -ne 0 ] ; then
     echo "Failed to create ports $POUDPORTS"
     mv /tmp/.poudriere.conf.$$ /usr/local/etc/poudriere.conf
     exit 1
   fi
   mv /tmp/.poudriere.conf.$$ /usr/local/etc/poudriere.conf
}

do_pcbsd_portmerge()
{
   # Copy our PCBSD port files
   merge_pcbsd_src_ports "${GITBRANCH}" "${PJPORTSDIR}"

   # 6/11/2014 - Disable ports INDEX creation. Looks like poudreire / pkgng
   # don't need / use it at all anyway, and it causes some failures in 
   # stable/current
   # 
   # Create the ports INDEX file
   # cd ${PJPORTSDIR}
   # make -C ${PJPORTSDIR} PORTSDIR=${PJPORTSDIR} __MAKE_CONF=/usr/local/etc/poudriere.d/$PBUILD-make.conf index
   # if [ $? -ne 0 ] ; then
   #    echo "Failed building port INDEX..."
   #    exit 1
   # fi

   # Make dist ports files
   #rm ${PROGDIR}/usr/ports 2>/dev/null
   #rmdir ${PROGDIR}/usr 2>/dev/null
   #rc_halt "mkdir ${PROGDIR}/usr"
   #rc_halt "ln -fs ${PJPORTSDIR} ${PROGDIR}/usr/ports"
   #echo "Creating ports distfile.. Will take several minutes.."
   #rc_halt "tar cLvJf ${DISTDIR}/ports.txz --exclude usr/ports/.portsnap.INDEX --exclude usr/ports/.snap --exclude usr/ports/distfiles --exclude usr/ports/.git -C ${PROGDIR} usr/ports" 2>/dev/null
   #rc_halt "rm ${PROGDIR}/usr/ports"
   #rc_halt "rmdir ${PROGDIR}/usr"
}

sign_pkg_repo()
{
   echo "Signing repo..."
   get_pkgstatic
   if [ -e "cd $PPKGDIR/.latest" ] ; then
     rc_halt "cd $PPKGDIR/.latest" >/dev/null 2>/dev/null
   else
     rc_halt "cd $PPKGDIR/" >/dev/null 2>/dev/null
   fi
   rc_halt "${PKGSTATIC} repo . ${POUD_SIGN_REPO}" >/dev/null 2>/dev/null
   rc_halt "rm ${PKGSTATIC}" >/dev/null 2>/dev/null
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

# Copy over our custom make options
if [ ! -d "/usr/local/etc/poudriere.d" ]; then
 mkdir -p /usr/local/etc/poudriere.d
fi
if [ ! -d "${GITBRANCH}" ]; then
   rc_halt "git clone ${GITPCBSDURL} ${GITBRANCH}"
fi
git_up "${GITBRANCH}" "${GITBRANCH}"
rc_halt "cd ${PCONFDIR}/" >/dev/null 2>/dev/null
cp ${PCONFDIR}/port-make.conf /usr/local/etc/poudriere.d/$PBUILD-make.conf
if [ -e "/usr/local/etc/poudriere.d/$PBUILD-make.conf.poudriere" ] ; then
  cat /usr/local/etc/poudriere.d/$PBUILD-make.conf.poudriere >> /usr/local/etc/poudriere.d/$PBUILD-make.conf
fi

# Running poudriere in verbose mode?
pV=""
if [ "$POUD_VERBOSE" = "YES" ] ; then
  pV="-vv"
fi

if [ "$target" = "all" ] ; then
   # Set cleanup var
   pCleanup="-j ${PBUILD} -p ${POUDPORTS}"
   export pCleanup

   # Remove old PBI-INDEX.txz files
   rm ${PPKGDIR}/PBI-INDEX.txz* 2>/dev/null

   # Make sure this builder isn't already going
   poudriere jail -k -j $PBUILD -p $POUDPORTS

   # Build entire ports tree
   poudriere bulk -a ${pV} -j $PBUILD -p $POUDPORTS | tee ${PROGDIR}/log/poudriere.log
   if [ $? -ne 0 ] ; then
      echo "Failed poudriere build..."
   fi

   # Make sure the essentials built, exit now if not
   check_essential_pkgs "NO"
   if [ $? -ne 0 ] ; then
      exit 1
   fi

   # If the user wanted to sign the repo lets do it now
   if [ -n "$POUD_SIGN_REPO" ] ; then
      sign_pkg_repo
   fi

   # Update the PBI index file
   do_pbi-index

   # Unset cleanup var
   pCleanup=""
   export pCleanup

   exit 0
elif [ "$target" = "meta" ] ; then
   bList="/tmp/.bulkList.$$"

   # Build specific meta-pkg list
   mk_metapkg_bulkfile "$bList"

   # Set cleanup var
   pCleanup="-j ${PBUILD} -p ${POUDPORTS}"
   export pCleanup

   # Make sure this builder isn't already going
   poudriere jail -k -j $PBUILD -p $POUDPORTS

   # Start the build
   poudriere bulk ${pV} -j $PBUILD -p $POUDPORTS -f $bList | tee ${PROGDIR}/log/poudriere.log
   if [ $? -ne 0 ] ; then
      echo "Failed poudriere build..."
   fi

   # Make sure the essentials built, exit now if not
   check_essential_pkgs "NO"
   if [ $? -ne 0 ] ; then
      exit 1
   fi

   # If the user wanted to sign the repo lets do it now
   if [ -n "$POUD_SIGN_REPO" ] ; then
      sign_pkg_repo
   fi

   # Unset cleanup var
   pCleanup=""
   export pCleanup

   exit 0
elif [ "$target" = "i386" ] ; then
   bList="${PROGDIR}/scripts/i386-pkgs"

   # Set cleanup var
   pCleanup="-j ${PBUILD} -p ${POUDPORTS}"
   export pCleanup

   # Make sure this builder isn't already going
   poudriere jail -k -j $PBUILD -p $POUDPORTS

   # Start the build
   poudriere bulk ${pV} -j $PBUILD -p $POUDPORTS -f $bList | tee ${PROGDIR}/log/poudriere.log
   if [ $? -ne 0 ] ; then
      echo "Failed poudriere build..."
   fi

   # Unset cleanup var
   pCleanup=""
   export pCleanup

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
