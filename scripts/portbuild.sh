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
   local svndir="$1"
   local portsdir="$2"
   local distCache=`grep '^DISTFILES_CACHE=' /usr/local/etc/poudriere.conf | cut -d '=' -f 2`
   if [ -z "$distCache" ] ; then
      exit_err "Need a DISTFILES_CACHE in poudriere.conf"
   fi

   if [ ! -d "$distCache" ] ; then rc_halt "mkdir -p ${distCache}" ; fi
   git_up "$svndir" "$svndir"
   rc_halt "cd ${svndir}"

     
   echo "Merging PC-BSD ports-overlay..."
   rc_halt "${PROGDIR}/scripts/mergesvnports ${svndir}/build-files/ports-overlay ${portsdir}"

   # Now massage all the CHGVERSION variables into the REV
   rc_halt "cd ${portsdir}/misc"
   for i in `ls -d pcbsd* trueos*`
   do
      mREV=`get_last_rev "${svndir}/build-files/ports-overlay/misc/${i}"`
      rc_halt "cd ${portsdir}/misc"
      if [ ! -e "${i}/Makefile" ] ; then
         exit_err "Error: missing Makefile for ${portsdir}/misc/${i}"
      fi
      sed -i '' "s|CHGVERSION|$mREV|g" ${i}/Makefile
      if [ $? -ne 0 ] ; then
         exit_err "Error: Failed running sed on ${portsdir}/misc/${i}"
      fi
   done

   # Make the dist files
   cliREV=`get_last_rev "${svndir}/src-sh"`
   guiREV=`get_last_rev "${svndir}/src-qt4"`
   rc_halt "cd ${svndir}"
   rc_nohalt "rm ${distCache}/pcbsd-utils*.bz2"

   echo "Creating dist files for version: $cliREV"
   rc_halt "tar cvjf ${distCache}/pcbsd-utils-${cliREV}.tar.bz2 src-sh" 2>/dev/null

   echo "Creating dist files for version: $guiREV"
   rc_halt "tar cvjf ${distCache}/pcbsd-utils-qt4-${guiREV}.tar.bz2 src-qt4" 2>/dev/null

   # Copy ports files
   rm -rf ${portsdir}/sysutils/pcbsd-utils 2>/dev/null
   rm -rf ${portsdir}/sysutils/pcbsd-utils-qt4 2>/dev/null
   rm -rf ${portsdir}/sysutils/pcbsd-base 2>/dev/null
   rm -rf ${portsdir}/sysutils/trueos-base 2>/dev/null
   rc_halt "cp -r src-sh/port-files ${portsdir}/sysutils/pcbsd-utils" 
   rc_halt "cp -r src-qt4/port-files ${portsdir}/sysutils/pcbsd-utils-qt4" 
   
   # Set the version numbers
   sed -i '' "s|CHGVERSION|${cliREV}|g" ${portsdir}/sysutils/pcbsd-utils/Makefile
   sed -i '' "s|CHGVERSION|${guiREV}|g" ${portsdir}/sysutils/pcbsd-utils-qt4/Makefile

   # Create the makesums / distinfo file
   rc_halt "cd ${portsdir}/sysutils/pcbsd-utils"
   rc_halt "make makesum DISTDIR=${distCache} PORTSDIR=${portsdir}"
   rc_halt "cd ${portsdir}/sysutils/pcbsd-utils-qt4"
   rc_halt "make makesum DISTDIR=${distCache} PORTSDIR=${portsdir}"

   # Need to add these ports to INDEX / SUBDIR
   rc_halt "cd ${svndir}/build-files/ports-overlay"
   for i in `find . | grep '/Makefile$' | sed 's|/Makefile||g' | sed 's|\./||g'`
   do
      rc_halt "cd ${svndir}/build-files/ports-overlay"
      if [ ! -d "$i" ] ; then echo "Invalid merge dir ${i}" ; continue ; fi
      cDir=`echo $i | cut -d '/' -f 1`
      pDir=`echo $i | cut -d '/' -f 2`

      rc_halt "cd ${portsdir}"
      grep -q "SUBDIR += ${pDir}\$" ${cDir}/Makefile
      if [ $? -eq 0 ] ; then continue; fi

      echo "Adding ${pDir} to ${cDir}/Makefile..."
      # Add to $cDir / Makefile
      mv ${cDir}/Makefile ${cDir}/Makefile.$$
      echo "    SUBDIR += ${pDir}" >${cDir}/Makefile
      cat ${cDir}/Makefile.$$ >> ${cDir}/Makefile
      rm ${cDir}/Makefile.$$
   done

   # Jump back to where we belong
   rc_halt "cd $mcwd"
}

mk_metapkg_bulkfile()
{
   local bulkList=$1
   rm $bulkList >/dev/null 2>/dev/null

   # Save the bulk file
   echo "==> Scheduling build for: sysutils/pcbsd-utils"
   echo "sysutils/pcbsd-utils" > $bulkList
   echo "==> Scheduling build for: sysutils/pcbsd-utils-qt4"
   echo "sysutils/pcbsd-utils-qt4" >> $bulkList
   
   # Get a listing of all pcbsd-* and trueos-* packages to build
   for i in `ls -d ${PJPORTSDIR}/misc/pcbsd-* ${PJPORTSDIR}/misc/trueos-* | sed "s|${PJPORTSDIR}/||g"`
   do
     # Check the arch type
     pArch=`make -C ${PJPORTSDIR}/${i} -V ONLY_FOR_ARCHS PORTSDIR=${PJPORTSDIR}`
     if [ -n "$pArch" -a "$pArch" != "$ARCH" ] ; then continue; fi
     echo "==> Scheduling build for: $i"
     echo "${i}" >> $bulkList
   done
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

   poudriere ports -c -m git -p "$POUDPORTS"
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

   # Create the ports INDEX file
   cd ${PJPORTSDIR}
   make -C ${PJPORTSDIR} PORTSDIR=${PJPORTSDIR} __MAKE_CONF=/usr/local/etc/poudriere.d/$PBUILD-make.conf index
   if [ $? -ne 0 ] ; then
      echo "Failed building port INDEX..."
      exit 1
   fi

   # Make dist ports files
   rm ${PROGDIR}/usr/ports 2>/dev/null
   rmdir ${PROGDIR}/usr 2>/dev/null
   rc_halt "mkdir ${PROGDIR}/usr"
   rc_halt "ln -fs ${PJPORTSDIR} ${PROGDIR}/usr/ports"
   echo "Creating ports distfile.. Will take several minutes.."
   rc_halt "tar cLvJf /usr/ports.txz --exclude usr/ports/.portsnap.INDEX --exclude usr/ports/.snap --exclude usr/ports/distfiles --exclude usr/ports/.git -C ${PROGDIR} usr/ports"
   rc_halt "rm ${PROGDIR}/usr/ports"
   rc_halt "rmdir ${PROGDIR}/usr"
}

sign_pkg_repo()
{
   echo "Signing repo..."
   if [ -e "/tmp/pkg-static" ] ; then rm /tmp/pkg-static; fi
   rc_halt "tar xv --strip-components 4 -f ${PPKGDIR}/Latest/pkg.txz -C /tmp /usr/local/sbin/pkg-static"
   rc_halt "mv /tmp/pkg-static /tmp/pkg-static.$$"
   rc_halt "cd $PPKGDIR"
   rc_halt "/tmp/pkg-static.$$ repo . ${POUD_SIGN_REPO}"
   rc_halt "rm /tmp/pkg-static.$$"
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
rc_halt "cd ${GITBRANCH}/build-files/conf/"
cp ${GITBRANCH}/build-files/conf/port-make.conf /usr/local/etc/poudriere.d/$PBUILD-make.conf
if [ -e "/usr/local/etc/poudriere.d/$PBUILD-make.conf.poudriere" ] ; then
  cat /usr/local/etc/poudriere.d/$PBUILD-make.conf.poudriere >> /usr/local/etc/poudriere.d/$PBUILD-make.conf
fi

# Running poudriere in verbose mode?
pV=""
if [ "$POUD_VERBOSE" = "YES" ] ; then
  pV="-v"
fi

if [ "$target" = "all" ] ; then
   # Set cleanup var
   pCleanup="-j ${PBUILD} -p ${POUDPORTS}"
   export pCleanup

   # Build entire ports tree
   poudriere bulk -a ${pV} -j $PBUILD -p $POUDPORTS | tee ${PROGDIR}/log/poudriere.log
   if [ $? -ne 0 ] ; then
      echo "Failed poudriere build..."
   fi

   # If the user wanted to sign the repo lets do it now
   if [ -n "$POUD_SIGN_REPO" ] ; then
      sign_pkg_repo
   fi

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

   poudriere bulk ${pV} -j $PBUILD -p $POUDPORTS -f $bList | tee ${PROGDIR}/log/poudriere.log
   if [ $? -ne 0 ] ; then
      echo "Failed poudriere build..."
   fi

   # If the user wanted to sign the repo lets do it now
   if [ -n "$POUD_SIGN_REPO" ] ; then
      sign_pkg_repo
   fi

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
else
   echo "Invalid option!"
   exit 1
fi
